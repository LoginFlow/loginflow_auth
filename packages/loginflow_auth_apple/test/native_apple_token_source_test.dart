// TEST_CHARTER
// Requirement: `NativeAppleTokenSource` passes the SHA-256 hex of the server's nonce
// straight through to `sign_in_with_apple` and maps its credential to
// `ObtainedUpstreamToken(tokenType: idToken)` carrying the given/family
// name (`doc/server-contract.md` §5.4).
// Oracle: the returned `ObtainedUpstreamToken` and the `nonce` argument
// the injected `GetAppleIdCredential` seam actually received.
// Risk edge: a cancelled Apple sheet must map to
// `UpstreamFailureReason.cancelled`, not a generic failure.
// Layer: unit, against the DI seam — the real `AuthenticationServices`
// ceremony is a platform/native boundary outside this package's control
// and is exercised through LoginFlow's own manual QA on-device, not here.
// Counterfactual: a seam returning no identity token must fail instead of
// silently reporting success.

import 'package:flutter_test/flutter_test.dart';
import 'package:loginflow_auth/loginflow_auth_core.dart';
import 'package:loginflow_auth_apple/loginflow_auth_apple.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

void main() {
  const prompt = UpstreamPrompt(
    provider: UpstreamProvider.apple,
    nonce: 'server-nonce-under-test',
    clientId: 'com.example.app.services',
  );

  test('the server nonce reaches the platform call and the credential maps '
      'to an id_token with the Apple name', () async {
    String? receivedNonce;
    final source = NativeAppleTokenSource(
      getCredential: ({required scopes, nonce}) async {
        receivedNonce = nonce;
        return const AuthorizationCredentialAppleID(
          userIdentifier: 'apple-user-id',
          givenName: 'Ana',
          familyName: 'Ruiz',
          authorizationCode: 'auth-code',
          identityToken: 'identity-token-under-test',
          state: null,
          email: 'ana@example.com',
        );
      },
    );

    final result = await source.obtainToken(prompt);

    // Apple expects the lowercase hex SHA-256 of the server nonce
    // (computed independently: `printf 'server-nonce-under-test' | shasum -a 256`).
    expect(
      receivedNonce,
      '17ebbc2cf8e2695874fc3ac8fbd7555723c89bd02e3cd2facfc6521d0c8bc682',
    );
    expect(
      result.data,
      const ObtainedUpstreamToken(
        token: 'identity-token-under-test',
        tokenType: UpstreamTokenType.idToken,
        givenName: 'Ana',
        familyName: 'Ruiz',
      ),
    );
  });

  test('a cancelled Apple sheet maps to UpstreamFailureReason.cancelled', () async {
    final source = NativeAppleTokenSource(
      getCredential: ({required scopes, nonce}) =>
          throw const SignInWithAppleAuthorizationException(
            code: AuthorizationErrorCode.canceled,
            message: 'cancelled',
          ),
    );

    final result = await source.obtainToken(prompt);

    expect(
      result.errorOrNull,
      const UpstreamFailed(
        provider: UpstreamProvider.apple,
        reason: UpstreamFailureReason.cancelled,
      ),
    );
  });
}
