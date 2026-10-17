import CryptoKit
import Foundation

enum DpopKeyError: Error {
    case keyUnavailable(String)
    case signingFailed(String)
}

/// A non-exportable P-256 (ES256) signing key per `alias`.
///
/// Uses `SecureEnclave.P256.Signing.PrivateKey` when the Secure Enclave is
/// available (real iOS devices, Apple Silicon Macs). Where it is not (the
/// Simulator, Intel Macs without a T2 chip), falls back to
/// `P256.Signing.PrivateKey` stored only in the Keychain
/// (`kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`, never
/// synchronizable): the key material still never leaves this process in
/// plain form over the method channel, only its public half and signatures
/// do. `CryptoKit.SecureEnclave.isAvailable` makes the choice once per key.
final class DpopSecureEnclaveKey {
    private let alias: String
    private let service = "dev.loginflow.auth.dpop"

    init(alias: String) {
        self.alias = alias
    }

    /// The key's public JWK (`alg: "ES256"`), generating one the first time.
    func ensurePublicJwk() throws -> [String: String] {
        let x963 = try loadOrGeneratePublicKeyRepresentation()
        // x9.63 uncompressed point: 0x04 || X (32 bytes) || Y (32 bytes).
        guard x963.count == 65, x963.first == 0x04 else {
            throw DpopKeyError.keyUnavailable("Malformed public key representation.")
        }
        let x = x963.subdata(in: 1..<33)
        let y = x963.subdata(in: 33..<65)
        return [
            "kty": "EC",
            "crv": "P-256",
            "x": x.base64UrlEncodedString(),
            "y": y.base64UrlEncodedString(),
        ]
    }

    /// Raw `R || S` (64 bytes) over `signingInput`, base64url without padding.
    func sign(_ signingInput: Data) throws -> String {
        let store = KeychainStore(service: service, accessGroup: nil)
        if SecureEnclave.isAvailable, let stored = try? store.read(account: alias), let data = Data(base64Encoded: stored) {
            let key = try SecureEnclave.P256.Signing.PrivateKey(dataRepresentation: data)
            let signature = try key.signature(for: signingInput)
            return signature.rawRepresentation.base64UrlEncodedString()
        }
        if let stored = try? store.read(account: alias), let data = Data(base64Encoded: stored) {
            let key = try P256.Signing.PrivateKey(rawRepresentation: data)
            let signature = try key.signature(for: signingInput)
            return signature.rawRepresentation.base64UrlEncodedString()
        }
        // No key yet: generating one here (instead of failing) keeps `sign`
        // usable on its own, matching the Android/web stores' "ensure on
        // first use" behaviour.
        _ = try loadOrGeneratePublicKeyRepresentation()
        return try sign(signingInput)
    }

    private func loadOrGeneratePublicKeyRepresentation() throws -> Data {
        let store = KeychainStore(service: service, accessGroup: nil)
        if let stored = try? store.read(account: alias), let privateData = Data(base64Encoded: stored) {
            if SecureEnclave.isAvailable, let key = try? SecureEnclave.P256.Signing.PrivateKey(dataRepresentation: privateData) {
                return key.publicKey.x963Representation
            }
            if let key = try? P256.Signing.PrivateKey(rawRepresentation: privateData) {
                return key.publicKey.x963Representation
            }
        }
        if SecureEnclave.isAvailable {
            let key = try SecureEnclave.P256.Signing.PrivateKey()
            try store.write(account: alias, value: key.dataRepresentation.base64EncodedString())
            return key.publicKey.x963Representation
        }
        let key = P256.Signing.PrivateKey()
        try store.write(account: alias, value: key.rawRepresentation.base64EncodedString())
        return key.publicKey.x963Representation
    }
}

extension Data {
    func base64UrlEncodedString() -> String {
        base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    init?(base64UrlEncoded text: String) {
        var base64 = text.replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
        base64 += String(repeating: "=", count: (4 - base64.count % 4) % 4)
        guard let data = Data(base64Encoded: base64) else { return nil }
        self = data
    }
}
