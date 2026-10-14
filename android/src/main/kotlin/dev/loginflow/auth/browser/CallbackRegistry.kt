package dev.loginflow.auth.browser

import android.net.Uri

/**
 * Hands the redirect received by [LoginFlowCallbackActivity] to the
 * [BrowserAuthenticator] waiting for it. Activities cannot be given a
 * reference to the plugin, so this process-wide handoff is the bridge.
 *
 * Only a URI matching the registered [ExpectedCallback] is consumed; any
 * other navigation (the activity is exported, so any app can send one) is
 * ignored and the listener stays registered for the real callback.
 */
internal object CallbackRegistry {
    @Volatile
    private var registration: Pair<ExpectedCallback, (Uri) -> Unit>? = null

    fun register(expected: ExpectedCallback, onCallback: (Uri) -> Unit) {
        registration = expected to onCallback
    }

    fun clear() {
        registration = null
    }

    fun deliver(uri: Uri): Boolean {
        val (expected, onCallback) = registration ?: return false
        if (!expected.matches(uri.scheme, uri.host, uri.path, uri.getQueryParameter("state"))) {
            return false
        }
        registration = null
        onCallback(uri)
        return true
    }
}
