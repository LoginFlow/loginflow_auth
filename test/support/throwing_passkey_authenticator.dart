import 'package:loginflow_auth/loginflow_auth_core.dart';

/// A [PasskeyAuthenticator] that breaks its own contract and throws instead
/// of returning a `PasskeyFailed` — an app-supplied adapter with a bug. The
/// sign-in UI must survive it.
class ThrowingPasskeyAuthenticator implements PasskeyAuthenticator {
  int calls = 0;

  @override
  Future<Result<Map<String, Object?>, LoginFlowError>> getAssertion({
    required Map<String, Object?> options,
  }) async {
    calls++;
    throw StateError('passkey adapter bug');
  }

  @override
  Future<Result<Map<String, Object?>, LoginFlowError>> createCredential({
    required Map<String, Object?> options,
  }) async {
    calls++;
    throw StateError('passkey adapter bug');
  }
}
