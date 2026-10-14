package dev.loginflow.auth.google

import android.app.Activity
import android.os.CancellationSignal
import android.os.Handler
import android.os.Looper
import androidx.credentials.CredentialManager
import androidx.credentials.CredentialManagerCallback
import androidx.credentials.CustomCredential
import androidx.credentials.GetCredentialRequest
import androidx.credentials.GetCredentialResponse
import androidx.credentials.exceptions.GetCredentialCancellationException
import androidx.credentials.exceptions.GetCredentialException
import androidx.credentials.exceptions.NoCredentialException
import com.google.android.libraries.identity.googleid.GetSignInWithGoogleOption
import com.google.android.libraries.identity.googleid.GoogleIdTokenCredential
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.Executor

/**
 * "Sign in with Google" through Credential Manager with a per-attempt nonce
 * (G-ANDROID-SIWG): the ID token is issued to the server client ID and
 * carries the nonce LoginFlow bound to the auth session.
 */
class LoginFlowAuthGooglePlugin : FlutterPlugin, MethodChannel.MethodCallHandler, ActivityAware {
    private var channel: MethodChannel? = null
    private var activity: Activity? = null
    private val mainExecutor = Executor { command -> Handler(Looper.getMainLooper()).post(command) }

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel = MethodChannel(binding.binaryMessenger, CHANNEL).also { it.setMethodCallHandler(this) }
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel?.setMethodCallHandler(null)
        channel = null
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activity = binding.activity
    }

    override fun onDetachedFromActivityForConfigChanges() {
        activity = null
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        activity = binding.activity
    }

    override fun onDetachedFromActivity() {
        activity = null
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        if (call.method != "getIdToken") {
            result.notImplemented()
            return
        }
        val current = activity
        val serverClientId = call.argument<String>("serverClientId")
        val nonce = call.argument<String>("nonce")
        if (current == null) {
            result.error("UNAVAILABLE", "No foreground activity.", null)
            return
        }
        if (serverClientId == null || nonce == null) {
            result.error("MISCONFIGURED", "serverClientId and nonce are required.", null)
            return
        }
        val option = GetSignInWithGoogleOption.Builder(serverClientId).setNonce(nonce).build()
        val request = GetCredentialRequest.Builder().addCredentialOption(option).build()
        CredentialManager.create(current).getCredentialAsync(
            current,
            request,
            CancellationSignal(),
            mainExecutor,
            object : CredentialManagerCallback<GetCredentialResponse, GetCredentialException> {
                override fun onResult(response: GetCredentialResponse) {
                    val credential = response.credential
                    val isGoogleToken = credential is CustomCredential &&
                        (credential.type == GoogleIdTokenCredential.TYPE_GOOGLE_ID_TOKEN_CREDENTIAL ||
                            credential.type == GoogleIdTokenCredential.TYPE_GOOGLE_ID_TOKEN_SIWG_CREDENTIAL)
                    if (isGoogleToken) {
                        result.success(GoogleIdTokenCredential.createFrom(credential.data).idToken)
                    } else {
                        result.error("FAILED", "Unexpected credential type.", null)
                    }
                }

                override fun onError(e: GetCredentialException) {
                    when (e) {
                        is GetCredentialCancellationException -> result.error("CANCELLED", e.message, null)
                        is NoCredentialException -> result.error("NO_CREDENTIAL", e.message, null)
                        else -> result.error("FAILED", e.message, null)
                    }
                }
            },
        )
    }

    private companion object {
        const val CHANNEL = "dev.loginflow.auth.google/native"
    }
}
