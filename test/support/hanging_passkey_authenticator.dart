import 'dart:async';

import 'package:loginflow_auth/loginflow_auth_core.dart';

/// A [PasskeyAuthenticator] whose ceremony never finishes — an app-supplied
/// adapter with no timeout of its own over a platform sheet that never
/// resolves. The sign-in UI must not stay busy forever.
class HangingPasskeyAuthenticator implements PasskeyAuthenticator {
  int calls = 0;

  @override
  Future<Result<Map<String, Object?>, LoginFlowError>> getAssertion({
    required Map<String, Object?> options,
  }) {
    calls++;
    return Completer<Result<Map<String, Object?>, LoginFlowError>>().future;
  }

  @override
  Future<Result<Map<String, Object?>, LoginFlowError>> createCredential({
    required Map<String, Object?> options,
  }) {
    calls++;
    return Completer<Result<Map<String, Object?>, LoginFlowError>>().future;
  }
}
