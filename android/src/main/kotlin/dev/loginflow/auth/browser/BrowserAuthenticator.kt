package dev.loginflow.auth.browser

import android.app.Activity
import android.app.Application
import android.content.ActivityNotFoundException
import android.net.Uri
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import androidx.browser.customtabs.CustomTabsIntent
import io.flutter.plugin.common.MethodChannel

/**
 * Runs the authorization request in a Custom Tab (the system browser,
 * RFC 8252 §6) and waits for [LoginFlowCallbackActivity]. If the app comes
 * back to the foreground without a callback, the user closed the tab.
 */
internal class BrowserAuthenticator {
    private val mainHandler = Handler(Looper.getMainLooper())
    private var activity: Activity? = null
    private var pending: MethodChannel.Result? = null
    private var isAwaitingReturn = false

    private val lifecycle = object : Application.ActivityLifecycleCallbacks {
        override fun onActivityResumed(resumed: Activity) {
            if (resumed === activity && isAwaitingReturn) {
                mainHandler.post(::cancelIfStillPending)
            }
        }

        override fun onActivityCreated(created: Activity, savedInstanceState: Bundle?) = Unit
        override fun onActivityStarted(started: Activity) = Unit
        override fun onActivityPaused(paused: Activity) = Unit
        override fun onActivityStopped(stopped: Activity) = Unit
        override fun onActivitySaveInstanceState(saved: Activity, outState: Bundle) = Unit
        override fun onActivityDestroyed(destroyed: Activity) = Unit
    }

    fun attach(activity: Activity) {
        this.activity = activity
        activity.application.registerActivityLifecycleCallbacks(lifecycle)
    }

    fun detach() {
        activity?.application?.unregisterActivityLifecycleCallbacks(lifecycle)
        activity = null
        finish { result -> result.error(UNAVAILABLE, "The activity went away.", null) }
    }

    fun authenticate(url: String, expected: ExpectedCallback, result: MethodChannel.Result) {
        val current = activity
        if (current == null) {
            result.error(UNAVAILABLE, "No foreground activity to open the browser from.", null)
            return
        }
        finish { previous -> previous.error(CANCELLED, "Superseded by a new request.", null) }
        pending = result
        CallbackRegistry.register(expected) { uri -> mainHandler.post { complete(uri) } }
        try {
            CustomTabsIntent.Builder().build().launchUrl(current, Uri.parse(url))
            isAwaitingReturn = true
        } catch (error: ActivityNotFoundException) {
            CallbackRegistry.clear()
            finish { failed -> failed.error(UNAVAILABLE, "No browser is installed.", null) }
        }
    }

    private fun complete(uri: Uri) {
        finish { result -> result.success(uri.toString()) }
    }

    private fun cancelIfStillPending() {
        CallbackRegistry.clear()
        finish { result -> result.error(CANCELLED, "The user closed the browser.", null) }
    }

    private fun finish(reply: (MethodChannel.Result) -> Unit) {
        val result = pending ?: return
        pending = null
        isAwaitingReturn = false
        reply(result)
    }

    companion object {
        const val CANCELLED = "CANCELLED"
        const val UNAVAILABLE = "UNAVAILABLE"
    }
}
