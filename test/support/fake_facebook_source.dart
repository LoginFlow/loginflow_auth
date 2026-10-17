import 'package:loginflow_auth/loginflow_auth_core.dart';

/// Plays `flutter_facebook_auth`: [tokenType] selects Limited Login
/// (`id_token`, with the server nonce) or classic login (`access_token`,
/// nonceless — same split the real SDK draws between iOS and Android).
class FakeFacebookSource implements UpstreamTokenSource {
  FakeFacebookSource({
    this.email = 'ana@example.com',
    this.tokenType = UpstreamTokenType.idToken,
  });

  final String email;
  final UpstreamTokenType tokenType;
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
          provider: UpstreamProvider.facebook,
          reason: UpstreamFailureReason.cancelled,
        ),
      );
    }
    final nonce = tokenType == UpstreamTokenType.accessToken
        ? 'none'
        : prompt.nonce;
    return Ok(
      ObtainedUpstreamToken(
        token: 'facebook:$nonce:$email',
        tokenType: tokenType,
      ),
    );
  }
}
