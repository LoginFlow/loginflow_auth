import 'package:loginflow_auth/src/core/error/login_flow_error.dart';
import 'package:loginflow_auth/src/core/protocol/challenge/upstream_prompt.dart';
import 'package:result_controller/result_controller.dart';

/// Obtains a Google ID token natively, without a browser.
///
/// Implemented by the optional `loginflow_auth_google` package (Credential
/// Manager on Android, GIDSignIn on iOS), so apps that do not offer Google
/// do not depend on any Google SDK. The token must be requested with
/// `serverClientId = prompt.clientId` and `nonce = prompt.nonce`
/// (`doc/decisions.md` D5).
abstract interface class GoogleIdTokenSource {
  /// A Google ID token for [prompt]: issued to `prompt.clientId` (the
  /// company's web client) and carrying `prompt.nonce`.
  Future<Result<String, LoginFlowError>> obtainIdToken(UpstreamPrompt prompt);
}
