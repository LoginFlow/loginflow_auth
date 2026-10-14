package dev.loginflow.auth.sso

import android.content.ContentValues
import android.content.Context
import android.util.Log
import dev.loginflow.auth.storage.EncryptedPreferences
import org.json.JSONException
import org.json.JSONObject

/**
 * The Native SSO entry across this app and its siblings: every app keeps an
 * encrypted copy behind its own [LoginFlowSsoProvider]; reads take the newest
 * copy, writes and deletes reach every sibling that is installed and signed
 * with the same certificate.
 */
internal class SsoBridge(
    private val context: Context,
    private val siblingAuthorities: List<String>,
) {
    private val ownStore = EncryptedPreferences.named(context, SsoContract.PREFERENCES_NAME)

    fun read(issuer: String): String? {
        val copies = buildList {
            ownStore.get(issuer)?.let(::add)
            trustedSiblings().forEach { authority -> querySibling(authority, issuer)?.let(::add) }
        }
        return copies.maxByOrNull(::updatedAt)
    }

    fun write(issuer: String, payload: String) {
        ownStore.put(issuer, payload)
        val values = ContentValues().apply {
            put(SsoContract.COLUMN_ISSUER, issuer)
            put(SsoContract.COLUMN_PAYLOAD, payload)
        }
        trustedSiblings().forEach { authority ->
            runCatchingIpc(authority) {
                context.contentResolver.insert(SsoContract.entriesUri(authority), values)
            }
        }
    }

    fun delete(issuer: String) {
        ownStore.remove(issuer)
        trustedSiblings().forEach { authority ->
            runCatchingIpc(authority) {
                context.contentResolver.delete(
                    SsoContract.entriesUri(authority),
                    SsoContract.SELECTION_ISSUER,
                    arrayOf(issuer),
                )
            }
        }
    }

    /**
     * Authorities whose provider is installed and belongs to a package signed
     * with this app's certificate. An app from another publisher that claims
     * a sibling's authority never receives the device secret.
     */
    private fun trustedSiblings(): List<String> = siblingAuthorities.filter { authority ->
        val providerPackage = context.packageManager.resolveContentProvider(authority, 0)?.packageName
        val isTrusted = SignatureTrust.isTrustedSibling(providerPackage, context.packageName) { packageName ->
            SsoContract.isSameSigner(context, packageName)
        }
        if (!isTrusted && providerPackage != null && providerPackage != context.packageName) {
            Log.w(TAG, "Ignoring $authority: signed by another certificate.")
        }
        isTrusted
    }

    private fun querySibling(authority: String, issuer: String): String? =
        runCatchingIpc(authority) {
            context.contentResolver.query(
                SsoContract.entriesUri(authority),
                arrayOf(SsoContract.COLUMN_PAYLOAD),
                SsoContract.SELECTION_ISSUER,
                arrayOf(issuer),
                null,
            )?.use { cursor -> if (cursor.moveToFirst()) cursor.getString(0) else null }
        }

    private fun <T> runCatchingIpc(authority: String, call: () -> T): T? = try {
        call()
    } catch (error: SecurityException) {
        Log.w(TAG, "Sibling $authority refused access: ${error.message}")
        null
    } catch (error: IllegalArgumentException) {
        Log.w(TAG, "Sibling $authority rejected the request: ${error.message}")
        null
    }

    private fun updatedAt(payload: String): Long = try {
        JSONObject(payload).optLong("updated_at", 0L)
    } catch (error: JSONException) {
        0L
    }

    private companion object {
        const val TAG = "LoginFlowAuth"
    }
}
