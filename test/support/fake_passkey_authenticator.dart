import 'package:loginflow_auth/loginflow_auth_core.dart';

import 'fake_login_flow_server.dart';

/// Plays Credential Manager / AuthenticationServices: returns a credential
/// response the fake server accepts only when it carries the registered
/// credential id.
class FakePasskeyAuthenticator implements PasskeyAuthenticator {
  FakePasskeyAuthenticator({
    this.credentialId = FakeLoginFlowServer.passkeyCredentialId,
  });

  final String credentialId;
  final List<Map<String, Object?>> assertionOptionsSeen =
      <Map<String, Object?>>[];

  /// The creation options of every enrollment, as the platform's passkey
  /// sheet receives them (`user.name`, `user.displayName`).
  final List<Map<String, Object?>> creationOptionsSeen =
      <Map<String, Object?>>[];
  bool shouldCancel = false;

  /// Makes [createCredential] fail the way the platform reports it
  /// (`PasskeyFailed` with this reason), as `CorbadoPasskeyAuthenticator`
  /// maps a platform error.
  PasskeyFailureReason? enrollmentFailure;

  @override
  Future<Result<Map<String, Object?>, LoginFlowError>> getAssertion({
    required Map<String, Object?> options,
  }) async {
    assertionOptionsSeen.add(options);
    if (shouldCancel) {
      return Err(
        const PasskeyFailed(reason: PasskeyFailureReason.userCancelled),
      );
    }
    return Ok(<String, Object?>{'id': credentialId, 'type': 'public-key'});
  }

  @override
  Future<Result<Map<String, Object?>, LoginFlowError>> createCredential({
    required Map<String, Object?> options,
  }) async {
    creationOptionsSeen.add(options);
    final failure = enrollmentFailure;
    if (failure != null) {
      return Err(PasskeyFailed(reason: failure));
    }
    if (shouldCancel) {
      return Err(
        const PasskeyFailed(reason: PasskeyFailureReason.userCancelled),
      );
    }
    return Ok(<String, Object?>{'id': credentialId, 'type': 'public-key'});
  }
}
