import 'package:loginflow_auth/src/core/error/login_flow_error.dart';
import 'package:loginflow_auth/src/core/error/passkey_failure_reason.dart';
import 'package:loginflow_auth/src/core/webauthn/passkey_authenticator.dart';
import 'package:result_controller/result_controller.dart';

/// [PasskeyAuthenticator] for a platform with no passkey API (Linux
/// desktop: no OS WebAuthn client a Flutter app can call). Every ceremony
/// fails as `PasskeyFailed(notSupported)` — never an exception — so the
/// sign-in UI reports it like any other unsupported device.
final class UnsupportedPlatformPasskeyAuthenticator
    implements PasskeyAuthenticator {
  const UnsupportedPlatformPasskeyAuthenticator();

  @override
  Future<Result<Map<String, Object?>, LoginFlowError>> getAssertion({
    required Map<String, Object?> options,
  }) async =>
      Err(const PasskeyFailed(reason: PasskeyFailureReason.notSupported));

  @override
  Future<Result<Map<String, Object?>, LoginFlowError>> createCredential({
    required Map<String, Object?> options,
  }) async =>
      Err(const PasskeyFailed(reason: PasskeyFailureReason.notSupported));
}
