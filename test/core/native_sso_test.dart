import 'package:flutter_test/flutter_test.dart';
import 'package:loginflow_auth/loginflow_auth_core.dart';
import 'package:loginflow_auth/src/core/id_token/id_token_expectations.dart';

import '../support/auth_fixture.dart';
import '../support/fake_login_flow_server.dart';
import '../support/test_signing_keys.dart';

void main() {
  late TestSigningKeys keys;
  late FakeLoginFlowServer server;

  setUpAll(() => keys = TestSigningKeys.generate());

  setUp(() async => server = await FakeLoginFlowServer.start(keys));

  tearDown(() => server.close());

  group('OpenID Connect Native SSO (draft 07)', () {
    test('app one stores device_secret + id_token; app two exchanges them '
        'for its own tokens', () async {
      final shared = InMemorySsoStore();
      final appOne = AuthFixture.create(server, ssoStore: shared);
      await appOne.auth.initialize();
      await appOne.auth.signInWithPassword(
        loginHint: 'ana@example.com',
        password: 'correct-horse',
      );

      expect(server.challengeRequests.first['scope'], contains('device_sso'));
      final entry = (await shared.read(server.issuerText)).data;
      expect(entry?.deviceSecret, startsWith('ds_'));

      final appTwo = AuthFixture.create(
        server,
        clientId: 'app-two',
        ssoStore: shared,
      );
      final initialized = await appTwo.auth.initialize();

      expect(
        initialized.data,
        const SsoAvailable(
          candidate: SsoCandidate(
            subject: 'cu_ana',
            name: 'Ana Ruiz',
            email: 'ana@example.com',
            companyId: FakeLoginFlowServer.companyId,
          ),
        ),
      );

      final continued = await appTwo.auth.continueWithSso();

      final session = (continued.data as SignedIn).session;
      expect(session.identity.subject, 'cu_ana');
      expect(session.isSsoBound, isTrue);
      final exchange = server.tokenRequests.last;
      expect(
        exchange['grant_type'],
        'urn:ietf:params:oauth:grant-type:token-exchange',
      );
      expect(exchange['client_id'], 'app-two');
      expect(exchange['audience'], server.issuerText);
      expect(exchange['subject_token'], entry?.idToken);
      expect(
        exchange['subject_token_type'],
        'urn:ietf:params:oauth:token-type:id_token',
      );
      expect(exchange['actor_token'], entry?.deviceSecret);
      expect(
        exchange['actor_token_type'],
        'urn:openid:params:token-type:device-secret',
      );
      final appOneRefresh = (await appOne.storedSession())?.refreshToken;
      final appTwoRefresh = (await appTwo.storedSession())?.refreshToken;
      expect(appTwoRefresh, isNot(appOneRefresh));
    });

    test(
      'a client outside the SSO group falls back to normal sign-in',
      () async {
        final shared = InMemorySsoStore();
        final appOne = AuthFixture.create(server, ssoStore: shared);
        await appOne.auth.initialize();
        await appOne.auth.signInWithPassword(
          loginHint: 'ana@example.com',
          password: 'correct-horse',
        );
        final outsider = AuthFixture.create(
          server,
          clientId: 'other-publisher-app',
          ssoStore: shared,
        );
        await outsider.auth.initialize();

        final result = await outsider.auth.continueWithSso();

        expect(
          result.data,
          const SignedOut(reason: SignOutReason.ssoUnavailable),
        );
      },
    );

    test('the code exchange presents the existing device_secret', () async {
      final shared = InMemorySsoStore();
      final appOne = AuthFixture.create(server, ssoStore: shared);
      await appOne.auth.initialize();
      await appOne.auth.signInWithPassword(
        loginHint: 'ana@example.com',
        password: 'correct-horse',
      );
      final secret = (await shared.read(server.issuerText)).data?.deviceSecret;
      await appOne.auth.signOut(SignOutScope.app);

      await appOne.auth.signInWithPassword(
        loginHint: 'ana@example.com',
        password: 'correct-horse',
      );

      expect(server.tokenRequests.last['device_secret'], secret);
    });
  });

  test('a device_secret without its ID token is never stored', () async {
    final shared = InMemorySsoStore();
    final appOne = AuthFixture.create(server, ssoStore: shared);
    await appOne.auth.initialize();
    await appOne.auth.signInWithPassword(
      loginHint: 'ana@example.com',
      password: 'correct-horse',
    );
    final original = (await shared.read(server.issuerText)).data;
    await shared.write(original!.copyWith(deviceSecret: 'ds_unknown'));
    server.omitsIdTokenOnRefresh = true;
    appOne.clock.advance(const Duration(minutes: 15));

    await appOne.auth.accessTokenFor(FakeLoginFlowServer.routesApi);

    expect(server.tokenRequests.last['device_secret'], 'ds_unknown');
    expect(
      (await shared.read(server.issuerText)).data?.deviceSecret,
      'ds_unknown',
    );
  });

  test('IdTokenExpectations round-trips through JSON', () {
    const expectations = IdTokenExpectations(
      audience: 'app-one',
      nonce: 'n',
      subject: 'cu_ana',
      allowExpired: true,
    );

    expect(IdTokenExpectations.fromJson(expectations.toJson()), expectations);
  });
}
