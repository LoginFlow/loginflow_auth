import AuthenticationServices
import Foundation

#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

enum WebAuthenticatorError: Error {
    case cancelled
    case unavailable(String)
    case failed(String)
}

/// The system browser for OAuth (RFC 8252 §6): ASWebAuthenticationSession
/// returns the callback only to this app, even if another app registers the
/// same scheme (APPLE-ASWAS). Never a WKWebView.
final class WebAuthenticator: NSObject, ASWebAuthenticationPresentationContextProviding {
    private var session: ASWebAuthenticationSession?

    func authenticate(
        url: URL,
        callbackScheme: String,
        callbackHost: String,
        callbackPath: String,
        prefersEphemeral: Bool,
        completion: @escaping (Result<URL, WebAuthenticatorError>) -> Void
    ) {
        let handler: ASWebAuthenticationSession.CompletionHandler = { [weak self] callbackURL, error in
            self?.session = nil
            if let callbackURL {
                completion(.success(callbackURL))
            } else if let sessionError = error as? ASWebAuthenticationSessionError,
                      sessionError.code == .canceledLogin {
                completion(.failure(.cancelled))
            } else {
                completion(.failure(.failed(error?.localizedDescription ?? "No callback URL.")))
            }
        }
        let newSession: ASWebAuthenticationSession
        if callbackScheme == "https" {
            guard #available(iOS 17.4, macOS 14.4, *) else {
                completion(.failure(.unavailable(
                    "https redirect URIs need iOS 17.4 or macOS 14.4; register a private-use scheme."
                )))
                return
            }
            newSession = ASWebAuthenticationSession(
                url: url,
                callback: .https(host: callbackHost, path: callbackPath),
                completionHandler: handler
            )
        } else {
            newSession = ASWebAuthenticationSession(
                url: url,
                callbackURLScheme: callbackScheme,
                completionHandler: handler
            )
        }
        newSession.presentationContextProvider = self
        newSession.prefersEphemeralWebBrowserSession = prefersEphemeral
        session?.cancel()
        session = newSession
        if !newSession.start() {
            session = nil
            completion(.failure(.unavailable("The authentication session could not start.")))
        }
    }

    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        #if os(iOS)
        let windows = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
        return windows.first { $0.isKeyWindow } ?? ASPresentationAnchor()
        #elseif os(macOS)
        return NSApplication.shared.keyWindow ?? ASPresentationAnchor()
        #endif
    }
}
