import Flutter
import GoogleSignIn
import UIKit

/// GIDSignIn with a per-attempt nonce (G-IOS-BACKEND): the ID token is
/// issued with the server client ID as audience and the nonce LoginFlow
/// bound to the auth session.
public final class LoginFlowAuthGooglePlugin: NSObject, FlutterPlugin {
    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(
            name: "dev.loginflow.auth.google/native",
            binaryMessenger: registrar.messenger()
        )
        let instance = LoginFlowAuthGooglePlugin()
        registrar.addMethodCallDelegate(instance, channel: channel)
        registrar.addApplicationDelegate(instance)
    }

    public func application(
        _ app: UIApplication,
        open url: URL,
        options: [UIApplication.OpenURLOptionsKey: Any] = [:]
    ) -> Bool {
        GIDSignIn.sharedInstance.handle(url)
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard call.method == "getIdToken" else {
            result(FlutterMethodNotImplemented)
            return
        }
        let arguments = call.arguments as? [String: Any] ?? [:]
        guard let serverClientId = arguments["serverClientId"] as? String,
              let nonce = arguments["nonce"] as? String
        else {
            result(FlutterError(code: "MISCONFIGURED", message: "serverClientId and nonce are required.", details: nil))
            return
        }
        let configuredClientId = arguments["iosClientId"] as? String
            ?? Bundle.main.object(forInfoDictionaryKey: "GIDClientID") as? String
        guard let clientId = configuredClientId else {
            result(FlutterError(code: "MISCONFIGURED", message: "Set GIDClientID or iosClientId.", details: nil))
            return
        }
        guard let presenter = Self.topViewController() else {
            result(FlutterError(code: "UNAVAILABLE", message: "No view controller to present from.", details: nil))
            return
        }
        GIDSignIn.sharedInstance.configuration = GIDConfiguration(
            clientID: clientId,
            serverClientID: serverClientId
        )
        GIDSignIn.sharedInstance.signIn(
            withPresenting: presenter,
            hint: nil,
            additionalScopes: nil,
            nonce: nonce
        ) { signInResult, error in
            if let signInError = error as? GIDSignInError, signInError.code == .canceled {
                result(FlutterError(code: "CANCELLED", message: "The user dismissed Google sign-in.", details: nil))
            } else if let token = signInResult?.user.idToken?.tokenString {
                result(token)
            } else {
                result(FlutterError(code: "FAILED", message: error?.localizedDescription, details: nil))
            }
        }
    }

    private static func topViewController() -> UIViewController? {
        let root = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow }?
            .rootViewController
        var top = root
        while let presented = top?.presentedViewController {
            top = presented
        }
        return top
    }
}
