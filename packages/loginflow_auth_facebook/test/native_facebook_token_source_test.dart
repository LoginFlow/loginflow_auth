// TEST_CHARTER
// Requirement: `NativeFacebookTokenSource` maps a `LimitedToken` to
// `UpstreamTokenType.idToken` and a `ClassicToken` to
// `UpstreamTokenType.accessToken` (`doc/server-contract.md` §5.4), without
// the caller having to know which platform ran.
// Oracle: the returned `ObtainedUpstreamToken.tokenType`.
// Risk edge: a cancelled Facebook sheet must map to
// `UpstreamFailureReason.cancelled`, not a generic failure.
// Layer: unit, against the DI seam — the real Facebook SDK ceremony is a
// platform/native boundary outside this package's control and is
// exercised through LoginFlow's own manual QA on-device, not here.
// Counterfactual: a `LoginStatus.success` with no access token must fail
// instead of silently reporting success.

import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loginflow_auth/loginflow_auth_core.dart';
import 'package:loginflow_auth_facebook/loginflow_auth_facebook.dart';

void main() {
  const prompt = UpstreamPrompt(
    provider: UpstreamProvider.facebook,
    nonce: 'server-nonce-under-test',
    clientId: '1234567890123456',
  );

  test('a LimitedToken maps to an id_token', () async {
    final source = NativeFacebookTokenSource(
      login: ({required loginTracking, nonce, permissions = const []}) async =>
          LoginResult(
            status: LoginStatus.success,
            accessToken: LimitedToken(
              tokenString: 'identity-token-under-test',
              userId: 'facebook-user-id',
              userName: 'Ana Ruiz',
              userEmail: 'ana@example.com',
              nonce: nonce ?? '',
            ),
          ),
    );

    final result = await source.obtainToken(prompt);

    expect(
      result.data,
      const ObtainedUpstreamToken(
        token: 'identity-token-under-test',
        tokenType: UpstreamTokenType.idToken,
      ),
    );
  });

  test('a ClassicToken maps to an access_token', () async {
    final source = NativeFacebookTokenSource(
      login: ({required loginTracking, nonce, permissions = const []}) async =>
          LoginResult(
            status: LoginStatus.success,
            accessToken: ClassicToken(
              tokenString: 'access-token-under-test',
              userId: 'facebook-user-id',
              expires: DateTime.now(),
              applicationId: '1234567890123456',
              grantedPermissions: const <String>['email'],
              declinedPermissions: const <String>[],
            ),
          ),
    );

    final result = await source.obtainToken(prompt);

    expect(
      result.data,
      const ObtainedUpstreamToken(
        token: 'access-token-under-test',
        tokenType: UpstreamTokenType.accessToken,
      ),
    );
  });

  test('a cancelled Facebook sheet maps to UpstreamFailureReason.cancelled', () async {
    final source = NativeFacebookTokenSource(
      login: ({required loginTracking, nonce, permissions = const []}) async =>
          LoginResult(status: LoginStatus.cancelled),
    );

    final result = await source.obtainToken(prompt);

    expect(
      result.errorOrNull,
      const UpstreamFailed(
        provider: UpstreamProvider.facebook,
        reason: UpstreamFailureReason.cancelled,
      ),
    );
  });
}
