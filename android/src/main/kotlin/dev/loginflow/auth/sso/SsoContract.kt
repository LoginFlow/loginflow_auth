package dev.loginflow.auth.sso

import android.content.Context
import android.content.pm.PackageManager
import android.net.Uri

/** Names shared by [LoginFlowSsoProvider] and [SsoBridge]. */
internal object SsoContract {
    const val PREFERENCES_NAME = "dev.loginflow.auth.sso"
    const val PATH_ENTRIES = "entries"
    const val COLUMN_ISSUER = "issuer"
    const val COLUMN_PAYLOAD = "payload"
    const val SELECTION_ISSUER = "issuer = ?"
    const val MIME_TYPE = "vnd.android.cursor.item/vnd.dev.loginflow.sso"

    fun entriesUri(authority: String): Uri = Uri.parse("content://$authority/$PATH_ENTRIES")

    /**
     * True only when [packageName] is signed with this app's certificate
     * (A-PERMDEF "verify that both apps are signed with the same
     * certificate before complying").
     */
    fun isSameSigner(context: Context, packageName: String): Boolean =
        context.packageManager.checkSignatures(context.packageName, packageName) ==
            PackageManager.SIGNATURE_MATCH
}
