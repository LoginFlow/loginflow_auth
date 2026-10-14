package dev.loginflow.auth.browser

import android.app.Activity
import android.content.Intent
import android.os.Bundle
import android.util.Log

/**
 * Receives the authorization redirect from the Custom Tab. The app declares
 * it with an intent filter for its redirect URI (an App Link with
 * `autoVerify`, RFC 8252 §7.2).
 *
 * A matching callback is forwarded and the app's task comes back to the
 * front, which closes the Custom Tab. Any other URI is ignored: the activity
 * just finishes, leaving the Custom Tab where the user is signing in.
 */
class LoginFlowCallbackActivity : Activity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        val uri = intent?.data
        val isDelivered = uri != null && CallbackRegistry.deliver(uri)
        if (isDelivered) {
            packageManager.getLaunchIntentForPackage(packageName)?.let { launch ->
                launch.addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP)
                startActivity(launch)
            }
        } else {
            Log.w(TAG, "Ignoring a navigation that is not the pending callback.")
        }
        finish()
    }

    private companion object {
        const val TAG = "LoginFlowAuth"
    }
}
