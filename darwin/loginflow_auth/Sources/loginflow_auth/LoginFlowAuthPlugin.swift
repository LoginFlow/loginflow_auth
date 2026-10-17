#if os(iOS)
import Flutter
import UIKit
#elseif os(macOS)
import AppKit
import FlutterMacOS
#endif

/// Apple side of `dev.loginflow.auth/native`: private Keychain storage, the
/// shared Native SSO Keychain access group and ASWebAuthenticationSession.
public final class LoginFlowAuthPlugin: NSObject, FlutterPlugin {
    private static let privateService = "dev.loginflow.auth.private"
    private static let ssoService = "dev.loginflow.auth.sso"

    private let authenticator = WebAuthenticator()
    private let storageQueue = DispatchQueue(label: "dev.loginflow.auth.storage")

    public static func register(with registrar: FlutterPluginRegistrar) {
        #if os(iOS)
        let messenger = registrar.messenger()
        #elseif os(macOS)
        let messenger = registrar.messenger
        #endif
        let channel = FlutterMethodChannel(name: "dev.loginflow.auth/native", binaryMessenger: messenger)
        registrar.addMethodCallDelegate(LoginFlowAuthPlugin(), channel: channel)
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        let arguments = call.arguments as? [String: Any] ?? [:]
        switch call.method {
        case "privateStore.read":
            runStorage(result) { try self.privateStore().read(account: required(arguments, "key")) }
        case "privateStore.write":
            runStorage(result) {
                try self.writePrivate(
                    key: required(arguments, "key"),
                    value: required(arguments, "value"),
                    sharedAccessGroup: arguments["sharedAccessGroup"] as? String
                )
                return nil
            }
        case "privateStore.delete":
            runStorage(result) {
                try self.privateStore().delete(account: required(arguments, "key"))
                return nil
            }
        case "sso.read":
            runStorage(result) {
                try self.ssoStore(arguments).read(account: required(arguments, "issuer"))
            }
        case "sso.write":
            runStorage(result) {
                try self.ssoStore(arguments).write(
                    account: required(arguments, "issuer"),
                    value: required(arguments, "value")
                )
                return nil
            }
        case "sso.delete":
            runStorage(result) {
                try self.ssoStore(arguments).delete(account: required(arguments, "issuer"))
                return nil
            }
        case "browser.authenticate":
            authenticate(arguments, result: result)
        case "dpop.ensureKey":
            runDpop(result) {
                let alias = try required(arguments, "alias")
                let jwk = try DpopSecureEnclaveKey(alias: alias).ensurePublicJwk()
                let json = try JSONSerialization.data(withJSONObject: ["key_id": alias, "public_jwk": jwk])
                return String(data: json, encoding: .utf8)
            }
        case "dpop.sign":
            runDpop(result) {
                let alias = try required(arguments, "alias")
                guard let input = Data(base64UrlEncoded: try required(arguments, "signingInput")) else {
                    throw PluginError.invalidArgument("signingInput is not valid base64url.")
                }
                return try DpopSecureEnclaveKey(alias: alias).sign(input)
            }
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    private func runDpop(_ result: @escaping FlutterResult, operation: @escaping () throws -> String?) {
        storageQueue.async {
            let reply: Any?
            do {
                reply = try operation()
            } catch PluginError.invalidArgument(let reason) {
                reply = FlutterError(code: "INVALID_ARGUMENT", message: reason, details: nil)
            } catch DpopKeyError.keyUnavailable(let reason) {
                reply = FlutterError(code: "STORAGE", message: reason, details: nil)
            } catch DpopKeyError.signingFailed(let reason) {
                reply = FlutterError(code: "STORAGE", message: reason, details: nil)
            } catch {
                reply = FlutterError(code: "STORAGE", message: error.localizedDescription, details: nil)
            }
            DispatchQueue.main.async { result(reply) }
        }
    }

    private func privateStore() -> KeychainStore {
        KeychainStore(service: Self.privateService, accessGroup: nil)
    }

    private func ssoStore(_ arguments: [String: Any]) throws -> KeychainStore {
        guard let group = arguments["accessGroup"] as? String, !group.isEmpty else {
            throw PluginError.invalidArgument("Native SSO needs NativeSsoOptions.appleAccessGroup.")
        }
        return KeychainStore(service: Self.ssoService, accessGroup: group)
    }

    /// Private items go to the app's default access group. If the app lists
    /// the shared SSO group first in `keychain-access-groups`, the system
    /// would put them there and sibling apps could read this app's refresh
    /// token; that is refused instead of silently allowed.
    private func writePrivate(key: String, value: String, sharedAccessGroup: String?) throws {
        let store = privateStore()
        try store.write(account: key, value: value)
        guard let sharedAccessGroup else { return }
        if try store.storedAccessGroup(account: key) == sharedAccessGroup {
            try store.delete(account: key)
            throw KeychainStoreError.misconfiguredAccessGroup(
                "List the app's own access group before \(sharedAccessGroup) in keychain-access-groups."
            )
        }
    }

    private func authenticate(_ arguments: [String: Any], result: @escaping FlutterResult) {
        guard let urlText = arguments["url"] as? String,
              let url = URL(string: urlText),
              let scheme = arguments["callbackScheme"] as? String
        else {
            result(FlutterError(code: "INVALID_ARGUMENT", message: "url and callbackScheme are required.", details: nil))
            return
        }
        authenticator.authenticate(
            url: url,
            callbackScheme: scheme,
            callbackHost: arguments["callbackHost"] as? String ?? "",
            callbackPath: arguments["callbackPath"] as? String ?? "",
            prefersEphemeral: arguments["prefersEphemeral"] as? Bool ?? false
        ) { outcome in
            DispatchQueue.main.async {
                switch outcome {
                case .success(let callback):
                    result(callback.absoluteString)
                case .failure(.cancelled):
                    result(FlutterError(code: "CANCELLED", message: "The user closed the browser.", details: nil))
                case .failure(.unavailable(let reason)):
                    result(FlutterError(code: "UNAVAILABLE", message: reason, details: nil))
                case .failure(.failed(let reason)):
                    result(FlutterError(code: "FAILED", message: reason, details: nil))
                }
            }
        }
    }

    private func runStorage(_ result: @escaping FlutterResult, operation: @escaping () throws -> String?) {
        storageQueue.async {
            let reply: Any?
            do {
                reply = try operation()
            } catch KeychainStoreError.misconfiguredAccessGroup(let reason) {
                reply = FlutterError(code: "MISCONFIGURED", message: reason, details: nil)
            } catch KeychainStoreError.status(let status) {
                reply = FlutterError(code: "STORAGE", message: "Keychain status \(status)", details: nil)
            } catch PluginError.invalidArgument(let reason) {
                reply = FlutterError(code: "INVALID_ARGUMENT", message: reason, details: nil)
            } catch {
                reply = FlutterError(code: "STORAGE", message: error.localizedDescription, details: nil)
            }
            DispatchQueue.main.async { result(reply) }
        }
    }
}

private enum PluginError: Error {
    case invalidArgument(String)
}

private func required(_ arguments: [String: Any], _ name: String) throws -> String {
    guard let value = arguments[name] as? String else {
        throw PluginError.invalidArgument("Missing argument '\(name)'.")
    }
    return value
}
