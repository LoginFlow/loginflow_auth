import 'package:loginflow_auth/loginflow_auth_core.dart';

/// Plays `sign_in_with_apple`: returns an ID token the fake server accepts
/// only if it carries the nonce the server issued for the session.
class FakeAppleSource implements UpstreamTokenSource {
  FakeAppleSource({
    this.email = 'ana@example.com',
    this.givenName,
    this.familyName,
  });

  final String email;
  final String? givenName;
  final String? familyName;
  final List<UpstreamPrompt> prompts = <UpstreamPrompt>[];
  bool shouldCancel = false;
  bool available = true;

  @override
  bool get isAvailable => available;

  @override
  Future<Result<ObtainedUpstreamToken, LoginFlowError>> obtainToken(
    UpstreamPrompt prompt,
  ) async {
    prompts.add(prompt);
    if (shouldCancel) {
      return Err(
        const UpstreamFailed(
          provider: UpstreamProvider.apple,
          reason: UpstreamFailureReason.cancelled,
        ),
      );
    }
    return Ok(
      ObtainedUpstreamToken(
        token: 'apple:${prompt.nonce}:$email',
        tokenType: UpstreamTokenType.idToken,
        givenName: givenName,
        familyName: familyName,
      ),
    );
  }
}
