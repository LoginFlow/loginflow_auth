import 'package:loginflow_auth/loginflow_auth_core.dart';

/// Plays Credential Manager / GIDSignIn: returns a token the fake server
/// accepts only if it carries the nonce the server issued for the session.
class FakeGoogleSource implements GoogleIdTokenSource {
  FakeGoogleSource({this.email = 'ana@example.com'});

  final String email;
  final List<UpstreamPrompt> prompts = <UpstreamPrompt>[];
  bool shouldCancel = false;

  @override
  Future<Result<String, LoginFlowError>> obtainIdToken(
    UpstreamPrompt prompt,
  ) async {
    prompts.add(prompt);
    if (shouldCancel) {
      return Err(
        const UpstreamFailed(
          provider: UpstreamProvider.google,
          reason: UpstreamFailureReason.cancelled,
        ),
      );
    }
    return Ok('google:${prompt.nonce}:$email');
  }
}
