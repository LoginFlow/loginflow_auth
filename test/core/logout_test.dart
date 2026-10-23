import 'package:flutter_test/flutter_test.dart';
import 'package:loginflow_auth/loginflow_auth_core.dart';

import '../support/auth_fixture.dart';
import '../support/fake_login_flow_server.dart';
import '../support/test_signing_keys.dart';

void main() {
  late TestSigningKeys keys;
  late FakeLoginFlowServer server;
  late InMemorySsoStore shared;
  late AuthFixture appOne;
  late AuthFixture appTwo;

  setUpAll(() => keys = TestSigningKeys.generate());

  setUp(() async {
    server = await FakeLoginFlowServer.start(keys);
    shared = InMemorySsoStore();
    appOne = AuthFixture.create(server, ssoStore: shared);
    await appOne.auth.initialize();
    await appOne.auth.signInWithPassword(
      loginHint: 'ana@example.com',
      password: 'correct-horse',
    );
    appTwo = AuthFixture.create(server, clientId: 'app-two', ssoStore: shared);
    await appTwo.auth.initialize();
    await appTwo.auth.continueWithSso();
  });

  tearDown(() => server.close());

  group('Logout levels (doc/decisions.md D14)', () {
    test(
      'app: revokes only this refresh token; the sibling stays signed in',
      () async {
        final refresh = (await appOne.storedSession())?.refreshToken;

        final result = await appOne.auth.signOut(SignOutScope.app);

        expect(
          result.data,
          const SignedOut(reason: SignOutReason.userRequested),
        );
        final revocation = server.revocationRequests.single;
        expect(revocation['token'], refresh);
        expect(revocation['token_type_hint'], 'refresh_token');
        expect(revocation['client_id'], 'app-one');
        expect(await appOne.storedSession(), isNull);
        expect((await shared.read(server.issuerText)).data, isNotNull);
        appTwo.clock.advance(const Duration(minutes: 15));
        expect(
          (await appTwo.auth.accessTokenFor(FakeLoginFlowServer.routesApi))
              .isOk,
          isTrue,
        );
      },
    );

    test(
      'device: ends the sid; the sibling is signed out at its next refresh',
      () async {
        final result = await appOne.auth.signOut(SignOutScope.device);

        expect(
          result.data,
          const SignedOut(reason: SignOutReason.userRequested),
        );
        expect(server.deviceLogoutTokens, hasLength(1));
        expect((await shared.read(server.issuerText)).data, isNull);

        appTwo.clock.advance(const Duration(minutes: 15));
        final sibling = await appTwo.auth.accessTokenFor(
          FakeLoginFlowServer.routesApi,
        );
        expect(sibling.errorOrNull, const SessionRevoked());
        expect(
          appTwo.auth.state,
          const SignedOut(reason: SignOutReason.sessionRevoked),
        );
      },
    );

    test(
      'device: a sibling that resumes notices the shared entry is gone',
      () async {
        await appOne.auth.signOut(SignOutScope.device);

        final verified = await appTwo.auth.verifyDeviceSession();

        expect(
          verified.data,
          const SignedOut(reason: SignOutReason.deviceSessionEnded),
        );
        expect(await appTwo.storedSession(), isNull);
      },
    );

    test('device: a session another app already ended is cleared locally, '
        'not kept alive by the refused logout', () async {
      await appOne.auth.signOut(SignOutScope.device);

      // appTwo still holds an unexpired access token of the ended `sid`:
      // the logout endpoint refuses it (`401`, `WWW-Authenticate`).
      final result = await appTwo.auth.signOut(SignOutScope.device);

      expect(
        result.data,
        const SignedOut(reason: SignOutReason.sessionRevoked),
      );
      expect(await appTwo.storedSession(), isNull);
      expect(server.deviceLogoutTokens, hasLength(1));
    });

    test('everywhere: every session of the user ends', () async {
      final result = await appOne.auth.signOut(SignOutScope.everywhere);

      expect(result.data, isA<SignedOut>());
      expect(server.globalLogoutTokens, hasLength(1));
      appTwo.clock.advance(const Duration(minutes: 15));
      expect(
        (await appTwo.auth.accessTokenFor(FakeLoginFlowServer.routesApi))
            .errorOrNull,
        const SessionRevoked(),
      );
    });

    test('browser: RP-initiated logout with id_token_hint and state', () async {
      final idToken = (await appOne.storedSession())?.idToken;

      final result = await appOne.auth.signOut(SignOutScope.browser);

      expect(result.data, const SignedOut(reason: SignOutReason.userRequested));
      final endSession = server.endSessionRequests.single.queryParameters;
      expect(endSession['id_token_hint'], idToken);
      expect(endSession['client_id'], 'app-one');
      expect(
        endSession['post_logout_redirect_uri'],
        'https://app.example.com/signed-out',
      );
      expect(endSession['state'], isNotEmpty);
      expect(server.revocationRequests, hasLength(1));
    });

    test('a tampered logout callback state is rejected', () async {
      appOne.browser.rewriteCallback = (callback) => callback.replace(
        queryParameters: <String, String>{'state': 'forged'},
      );

      final result = await appOne.auth.signOut(SignOutScope.browser);

      expect(
        result.errorOrNull,
        const AuthorizationResponseRejected(
          problem: AuthorizationResponseProblem.stateMismatch,
        ),
      );
    });
  });
}
