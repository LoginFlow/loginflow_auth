import 'package:loginflow_auth/src/core/dpop/dpop_key_handle.dart';
import 'package:loginflow_auth/src/core/error/login_flow_error.dart';
import 'package:result_controller/result_controller.dart';

/// A platform-held, non-exportable ES256 signing key for DPoP proofs
/// (RFC 9449). Implementations never let the private key leave secure
/// hardware or browser-managed storage:
///
/// - iOS/macOS: the Secure Enclave (falling back to a Keychain-only key where
///   the Secure Enclave is unavailable, e.g. the Simulator).
/// - Android: the Android Keystore, backed by StrongBox when the device has
///   one.
/// - Web: a non-extractable WebCrypto `CryptoKey`.
abstract interface class DpopKeyStore {
  /// Returns the existing key, generating one the first time this app runs.
  Future<Result<DpopKeyHandle, LoginFlowError>> ensureKey();

  /// Signs [signingInput] (the JWS signing input, ASCII) with the key named
  /// by [keyId], returning the raw `R || S` signature (64 bytes for P-256),
  /// base64url-encoded (RFC 7518 §3.4).
  Future<Result<String, LoginFlowError>> sign(
    List<int> signingInput, {
    required String keyId,
  });
}
