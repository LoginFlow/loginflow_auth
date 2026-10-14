package dev.loginflow.auth.sso

import android.content.ContentProvider
import android.content.ContentValues
import android.content.Context
import android.content.pm.PackageManager
import android.database.Cursor
import android.database.MatrixCursor
import android.net.Uri
import android.os.Binder
import android.os.Process
import dev.loginflow.auth.storage.EncryptedPreferences

/**
 * Serves this app's copy of the Native SSO entry to sibling apps of the same
 * publisher. The app declares it in its manifest guarded by a
 * `signature`-level permission (A-SECTIPS, A-PERMDEF); the provider also
 * checks the caller's signing certificate itself, so a misconfigured
 * manifest cannot leak the device secret.
 */
class LoginFlowSsoProvider : ContentProvider() {
    override fun onCreate(): Boolean = true

    override fun query(
        uri: Uri,
        projection: Array<out String>?,
        selection: String?,
        selectionArgs: Array<out String>?,
        sortOrder: String?,
    ): Cursor {
        val context = verifiedContext()
        val cursor = MatrixCursor(arrayOf(SsoContract.COLUMN_PAYLOAD))
        val issuer = selectionArgs?.firstOrNull() ?: return cursor
        store(context).get(issuer)?.let { payload -> cursor.addRow(arrayOf(payload)) }
        return cursor
    }

    override fun insert(uri: Uri, values: ContentValues?): Uri {
        val context = verifiedContext()
        val issuer = values?.getAsString(SsoContract.COLUMN_ISSUER)
        val payload = values?.getAsString(SsoContract.COLUMN_PAYLOAD)
        require(issuer != null && payload != null) { "issuer and payload are required" }
        store(context).put(issuer, payload)
        return uri
    }

    override fun delete(uri: Uri, selection: String?, selectionArgs: Array<out String>?): Int {
        val context = verifiedContext()
        val issuer = selectionArgs?.firstOrNull() ?: return 0
        store(context).remove(issuer)
        return 1
    }

    override fun update(
        uri: Uri,
        values: ContentValues?,
        selection: String?,
        selectionArgs: Array<out String>?,
    ): Int {
        insert(uri, values)
        return 1
    }

    override fun getType(uri: Uri): String = SsoContract.MIME_TYPE

    private fun verifiedContext(): Context {
        val context = context ?: throw SecurityException("Provider not attached.")
        val callerUid = Binder.getCallingUid()
        val ownUid = Process.myUid()
        val isTrusted = SignatureTrust.isTrustedCaller(callerUid, ownUid) {
            context.packageManager.checkSignatures(callerUid, ownUid) == PackageManager.SIGNATURE_MATCH
        }
        if (!isTrusted) {
            throw SecurityException("Caller is not signed with this publisher's certificate.")
        }
        return context
    }

    private fun store(context: Context) =
        EncryptedPreferences.named(context, SsoContract.PREFERENCES_NAME)
}
