// TEST_CHARTER
// Requirement: `LoginFlowAuth` generalizes the `upstream_token` step so
// Apple and Facebook reach a signed-in, DPoP-bound session through the
// exact same prompt -> token -> code -> tokens pipeline Google already
// uses (`doc/server-contract.md` §5.4, §13) — with NO per-provider branch
// in `_answerUpstream`.
// Oracle: `SignedIn` carrying the fake server's `cu_ana` subject, the
// fake server's own form-field echo (`upstream_provider`,
// `upstream_token_type`, the nonce round trip) and, for DPoP, the real
// proof validation `acceptedDpopThumbprints` records (not a mock
// expectation).
// Risk edge: the two token shapes a federated provider can produce
// (Apple/Facebook-iOS `id_token`, bound to the server nonce; Facebook
// Android `access_token`, nonceless) must both reach the token endpoint
// correctly typed as `upstream_token_type`.
// Layer: core, against the fake server's real challenge/token/DPoP
// validation.
// Counterfactual: a provider with no source registered falls back to
// `upstream_flow: browser` instead of ever calling `obtainToken` — proving
// the native path above is exercised because a source IS registered, not
// because the server ignores the distinction.

import 'package:flutter_test/flutter_test.dart';
import 'package:loginflow_auth/loginflow_auth_core.dart';

import '../support/auth_fixture.dart';
import '../support/fake_apple_source.dart';
import '../support/fake_facebook_source.dart';
import '../support/fake_login_flow_server.dart';
import '../support/test_dpop_key_store.dart';
import '../support/test_signing_keys.dart';

void main() {
  late TestSigningKeys keys;
  late FakeLoginFlowServer server;

  setUpAll(() => keys = TestSigningKeys.generate());

  setUp(() async => server = await FakeLoginFlowServer.start(keys));

  tearDown(() => server.close());

  test(
    'Apple natively: the server nonce reaches the SDK and back, carrying '
    'id_token and the first-authorization name',
    () async {
      final apple = FakeAppleSource(givenName: 'Ana', familyName: 'Ruiz');
      final fixture = AuthFixture.create(server, apple: apple);
      await fixture.auth.initialize();

      final result = await fixture.auth.signInWithApple();

      expect(result.data, isA<SignedIn>());
      expect(
        (result.data as SignedIn).session.identity.subject,
        'cu_ana',
      );
      final prompt = apple.prompts.single;
      expect(server.challengeRequests.first['upstream_flow'], 'native');
      expect(server.challengeRequests.first['upstream_provider'], 'apple');
      final tokenRequest = server.challengeRequests.last;
      expect(tokenRequest['upstream_token'], 'apple:${prompt.nonce}:ana@example.com');
      expect(tokenRequest['upstream_token_type'], 'id_token');
      expect(tokenRequest['upstream_user_name'], 'Ana Ruiz');
    },
  );

  test('a cancelled Apple sheet returns to signed out', () async {
    final apple = FakeAppleSource()..shouldCancel = true;
    final fixture = AuthFixture.create(server, apple: apple);
    await fixture.auth.initialize();

    final result = await fixture.auth.signInWithApple();

    expect(
      result.errorOrNull,
      const UpstreamFailed(
        provider: UpstreamProvider.apple,
        reason: UpstreamFailureReason.cancelled,
      ),
    );
  });

  test(
    'Apple without a registered source falls back to the hosted page',
    () async {
      final fixture = AuthFixture.create(server);
      await fixture.auth.initialize();

      final result = await fixture.auth.signInWithApple();

      expect(result.data, isA<SignedIn>());
      expect(server.challengeRequests.single['upstream_flow'], 'browser');
    },
  );

  test(
    'Facebook Limited Login (iOS shape): id_token bound to the server '
    'nonce signs in',
    () async {
      final facebook = FakeFacebookSource();
      final fixture = AuthFixture.create(server, facebook: facebook);
      await fixture.auth.initialize();

      final result = await fixture.auth.signInWithFacebook();

      expect(result.data, isA<SignedIn>());
      final tokenRequest = server.challengeRequests.last;
      expect(tokenRequest['upstream_token_type'], 'id_token');
    },
  );

  test(
    'Facebook classic login (Android shape): nonceless access_token signs '
    'in',
    () async {
      final facebook = FakeFacebookSource(
        tokenType: UpstreamTokenType.accessToken,
      );
      final fixture = AuthFixture.create(server, facebook: facebook);
      await fixture.auth.initialize();

      final result = await fixture.auth.signInWithFacebook();

      expect(result.data, isA<SignedIn>());
      final tokenRequest = server.challengeRequests.last;
      expect(tokenRequest['upstream_token_type'], 'access_token');
    },
  );

  test(
    'Facebook without a registered source falls back to the hosted page',
    () async {
      final fixture = AuthFixture.create(server);
      await fixture.auth.initialize();

      final result = await fixture.auth.signInWithFacebook();

      expect(result.data, isA<SignedIn>());
      expect(server.challengeRequests.single['upstream_flow'], 'browser');
    },
  );

  test(
    'Apple sign-in against a DPoP-requiring server binds the issued '
    'tokens to the same proving key as the challenge request',
    () async {
      final dpopServer = FakeLoginFlowServer.inMemory(keys)
        ..requiresDpop = true;
      final auth = LoginFlowAuth(
        config: LoginFlowConfig(
          issuer: dpopServer.issuer,
          clientId: 'app-one',
          redirectUri: Uri.parse('https://app.example.com/oauth/callback'),
          enableDpop: true,
        ),
        httpClient: dpopServer.client,
        sessionStore: InMemorySessionStore(),
        pendingAuthorizationStore: InMemoryPendingAuthorizationStore(),
        appleTokenSource: FakeAppleSource(),
        dpopKeyStore: TestDpopKeyStore(),
      );

      final result = await auth.signInWithApple();

      expect(result.data, isA<SignedIn>());
      // 2 challenge legs (the opening `upstream_provider` prompt, then the
      // `upstream_token` submission) plus the token-endpoint exchange.
      expect(dpopServer.acceptedDpopThumbprints, hasLength(3));
      expect(
        dpopServer.acceptedDpopThumbprints.toSet(),
        hasLength(1),
        reason: 'every request of the attempt must use the same key',
      );
    },
  );
}
