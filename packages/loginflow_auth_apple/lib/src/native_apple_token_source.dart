import 'package:flutter/foundation.dart';
import 'package:loginflow_auth/loginflow_auth_core.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

/// The platform call this source wraps — overridable in tests so the
/// `AuthenticationServices` ceremony itself (unavailable off-device) is
/// never exercised, only the mapping to [ObtainedUpstreamToken].
typedef GetAppleIdCredential = Future<AuthorizationCredentialAppleID> Function({
  required List<AppleIDAuthorizationScopes> scopes,
  String? nonce,
});

/// [UpstreamTokenSource] over `AuthenticationServices`
/// ("Sign in with Apple") on iOS and macOS.
///
/// The ID token is requested with `nonce: prompt.nonceSha256Hex` — the
/// lowercase hex SHA-256 of the nonce the server bound to this attempt, as
/// Apple recommends. `sign_in_with_apple` forwards it unchanged to
/// `ASAuthorizationAppleIDRequest.nonce`, Apple returns it in the
/// `identityToken`'s `nonce` claim, and the server compares that claim with
/// the digest it stored (`doc/server-contract.md` §5.4). Deliberately **not**
/// used on Android or the web: `LoginFlowAuth` reports [isAvailable] `false`
/// there and falls back to the hosted page in the system browser instead of
/// Apple's own web authentication flow (`doc/decisions.md`).
final class NativeAppleTokenSource implements UpstreamTokenSource {
  const NativeAppleTokenSource({GetAppleIdCredential? getCredential})
    : _getCredential = getCredential ?? SignInWithApple.getAppleIDCredential;

  final GetAppleIdCredential _getCredential;

  @override
  bool get isAvailable =>
      defaultTargetPlatform == TargetPlatform.iOS ||
      defaultTargetPlatform == TargetPlatform.macOS;

  @override
  Future<Result<ObtainedUpstreamToken, LoginFlowError>> obtainToken(
    UpstreamPrompt prompt,
  ) async {
    try {
      final credential = await _getCredential(
        scopes: const <AppleIDAuthorizationScopes>[
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
        nonce: prompt.nonceSha256Hex,
      );
      final identityToken = credential.identityToken;
      if (identityToken == null || identityToken.isEmpty) {
        return Err(_failed(UpstreamFailureReason.failed));
      }
      return Ok(
        ObtainedUpstreamToken(
          token: identityToken,
          tokenType: UpstreamTokenType.idToken,
          givenName: credential.givenName,
          familyName: credential.familyName,
        ),
      );
    } on SignInWithAppleAuthorizationException catch (error) {
      return Err(
        _failed(switch (error.code) {
          AuthorizationErrorCode.canceled => UpstreamFailureReason.cancelled,
          AuthorizationErrorCode.notHandled ||
          AuthorizationErrorCode.notInteractive ||
          AuthorizationErrorCode.invalidResponse =>
            UpstreamFailureReason.notConfigured,
          AuthorizationErrorCode.failed ||
          AuthorizationErrorCode.unknown ||
          AuthorizationErrorCode.credentialExport ||
          AuthorizationErrorCode.credentialImport ||
          AuthorizationErrorCode.matchedExcludedCredential =>
            UpstreamFailureReason.failed,
        }),
      );
    }
  }

  UpstreamFailed _failed(UpstreamFailureReason reason) =>
      UpstreamFailed(provider: UpstreamProvider.apple, reason: reason);
}
