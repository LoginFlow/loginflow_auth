import 'package:loginflow_auth/src/core/error/login_flow_error.dart';
import 'package:result_controller/result_controller.dart';

/// Runs the two WebAuthn L3 ceremonies the platform's passkey provider
/// exposes (Android Credential Manager, iOS/macOS AuthenticationServices).
///
/// Implemented by an optional adapter package wrapping a platform passkey
/// SDK (e.g. the `passkeys` pub package by Corbado), the same shape as
/// [GoogleIdTokenSource]: apps that do not offer passkeys do not depend on
/// any passkey SDK. Every `options`/credential payload is the raw JSON this
/// server's `webauthn-rs` sends or expects — the library never reshapes it,
/// it only moves it between the server and the platform call
/// (`doc/server-contract.md` passkeys section).
abstract interface class PasskeyAuthenticator {
  /// Runs `navigator.credentials.get()` (or the platform equivalent) against
  /// the authentication `options` from `method=webauthn_identify`. Returns
  /// the raw `PublicKeyCredential` JSON to send back as
  /// `WebauthnAssertionInput`.
  Future<Result<Map<String, Object?>, LoginFlowError>> getAssertion({
    required Map<String, Object?> options,
  });

  /// Runs `navigator.credentials.create()` (or the platform equivalent)
  /// against the registration `options` from `POST
  /// /v1/user/passkeys/enroll/start`. Returns the raw `PublicKeyCredential`
  /// JSON to send to `POST /v1/user/passkeys/enroll/finish`.
  Future<Result<Map<String, Object?>, LoginFlowError>> createCredential({
    required Map<String, Object?> options,
  });
}
