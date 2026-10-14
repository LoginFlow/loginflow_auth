package dev.loginflow.auth

import android.content.Context
import android.os.Handler
import android.os.Looper
import dev.loginflow.auth.browser.BrowserAuthenticator
import dev.loginflow.auth.browser.ExpectedCallback
import dev.loginflow.auth.sso.SsoBridge
import dev.loginflow.auth.storage.EncryptedPreferences
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.security.GeneralSecurityException
import java.security.ProviderException
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors

/**
 * Android side of `dev.loginflow.auth/native`: private encrypted storage,
 * the shared Native SSO entry and the Custom Tabs browser. Storage and IPC
 * run on a background thread; replies go back on the main thread.
 */
class LoginFlowAuthPlugin : FlutterPlugin, MethodChannel.MethodCallHandler, ActivityAware {
    private var channel: MethodChannel? = null
    private var context: Context? = null
    private var executor: ExecutorService? = null
    private val mainHandler = Handler(Looper.getMainLooper())
    private val browser = BrowserAuthenticator()

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        context = binding.applicationContext
        executor = Executors.newSingleThreadExecutor()
        channel = MethodChannel(binding.binaryMessenger, CHANNEL).also {
            it.setMethodCallHandler(this)
        }
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel?.setMethodCallHandler(null)
        channel = null
        executor?.shutdown()
        executor = null
        context = null
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) = browser.attach(binding.activity)

    override fun onDetachedFromActivityForConfigChanges() = browser.detach()

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) =
        browser.attach(binding.activity)

    override fun onDetachedFromActivity() = browser.detach()

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        val appContext = context
        if (appContext == null) {
            result.error(UNAVAILABLE, "Plugin is not attached.", null)
            return
        }
        when (call.method) {
            "privateStore.read" -> runStorage(result) {
                privateStore(appContext).get(call.requiredString("key"))
            }
            "privateStore.write" -> runStorage(result) {
                privateStore(appContext).put(call.requiredString("key"), call.requiredString("value"))
                null
            }
            "privateStore.delete" -> runStorage(result) {
                privateStore(appContext).remove(call.requiredString("key"))
                null
            }
            "sso.read" -> runStorage(result) {
                ssoBridge(appContext, call).read(call.requiredString("issuer"))
            }
            "sso.write" -> runStorage(result) {
                ssoBridge(appContext, call).write(call.requiredString("issuer"), call.requiredString("value"))
                null
            }
            "sso.delete" -> runStorage(result) {
                ssoBridge(appContext, call).delete(call.requiredString("issuer"))
                null
            }
            "browser.authenticate" -> {
                val url = call.argument<String>("url")
                val scheme = call.argument<String>("callbackScheme")
                val state = call.argument<String>("state")
                if (url == null || scheme == null || state == null) {
                    result.error(INVALID_ARGUMENT, "url, callbackScheme and state are required.", null)
                } else {
                    val expected = ExpectedCallback(
                        scheme = scheme,
                        host = call.argument<String>("callbackHost").orEmpty(),
                        path = call.argument<String>("callbackPath").orEmpty(),
                        state = state,
                    )
                    browser.authenticate(url, expected, result)
                }
            }
            else -> result.notImplemented()
        }
    }

    private fun runStorage(result: MethodChannel.Result, operation: () -> String?) {
        val worker = executor
        if (worker == null) {
            result.error(UNAVAILABLE, "Plugin is not attached.", null)
            return
        }
        worker.execute {
            try {
                val value = operation()
                mainHandler.post { result.success(value) }
            } catch (error: GeneralSecurityException) {
                mainHandler.post { result.error(STORAGE, error.message, null) }
            } catch (error: IllegalArgumentException) {
                mainHandler.post { result.error(STORAGE, error.message, null) }
            } catch (error: ProviderException) {
                mainHandler.post { result.error(STORAGE, error.message, null) }
            }
        }
    }

    private fun privateStore(appContext: Context) =
        EncryptedPreferences.named(appContext, PRIVATE_PREFERENCES)

    private fun ssoBridge(appContext: Context, call: MethodCall) = SsoBridge(
        appContext,
        call.argument<List<String>>("authorities").orEmpty(),
    )

    private fun MethodCall.requiredString(name: String): String =
        argument<String>(name) ?: throw IllegalArgumentException("Missing argument '$name'.")

    private companion object {
        const val CHANNEL = "dev.loginflow.auth/native"
        const val PRIVATE_PREFERENCES = "dev.loginflow.auth.private"
        const val STORAGE = "STORAGE"
        const val INVALID_ARGUMENT = "INVALID_ARGUMENT"
        const val UNAVAILABLE = "UNAVAILABLE"
    }
}
