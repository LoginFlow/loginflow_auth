import 'package:flutter/foundation.dart';
import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';
import 'package:loginflow_auth/loginflow_auth_core.dart';

/// The platform call this source wraps — overridable in tests so the native
/// Facebook SDK ceremony (unavailable off-device) is never exercised, only
/// the mapping to [ObtainedUpstreamToken].
typedef FacebookLogin =
    Future<LoginResult> Function({
      required LoginTracking loginTracking,
      String? nonce,
      List<String> permissions,
    });

/// [UpstreamTokenSource] over the Facebook SDK: Limited Login on iOS (an
/// OIDC `id_token` bound to [UpstreamPrompt.nonce]) and classic login on
/// Android (a nonceless `access_token`) — `doc/server-contract.md` §5.4.
final class NativeFacebookTokenSource implements UpstreamTokenSource {
  NativeFacebookTokenSource({FacebookLogin? login})
    : _login = login ?? FacebookAuth.instance.login;

  final FacebookLogin _login;

  @override
  bool get isAvailable =>
      defaultTargetPlatform == TargetPlatform.iOS ||
      defaultTargetPlatform == TargetPlatform.android;

  @override
  Future<Result<ObtainedUpstreamToken, LoginFlowError>> obtainToken(
    UpstreamPrompt prompt,
  ) async {
    final isLimitedLogin = defaultTargetPlatform == TargetPlatform.iOS;
    final result = await _login(
      loginTracking: isLimitedLogin
          ? LoginTracking.limited
          : LoginTracking.enabled,
      nonce: isLimitedLogin ? prompt.nonce : null,
      permissions: const <String>['email', 'public_profile'],
    );
    return switch (result.status) {
      LoginStatus.success => _tokenOf(result.accessToken),
      LoginStatus.cancelled => Err(_failed(UpstreamFailureReason.cancelled)),
      LoginStatus.operationInProgress ||
      LoginStatus.failed => Err(_failed(UpstreamFailureReason.failed)),
    };
  }

  Result<ObtainedUpstreamToken, LoginFlowError> _tokenOf(
    AccessToken? accessToken,
  ) {
    final token = accessToken?.tokenString;
    if (token == null || token.isEmpty) {
      return Err(_failed(UpstreamFailureReason.failed));
    }
    return Ok(
      ObtainedUpstreamToken(
        token: token,
        tokenType: accessToken is LimitedToken
            ? UpstreamTokenType.idToken
            : UpstreamTokenType.accessToken,
      ),
    );
  }

  UpstreamFailed _failed(UpstreamFailureReason reason) =>
      UpstreamFailed(provider: UpstreamProvider.facebook, reason: reason);
}
