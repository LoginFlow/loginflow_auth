import 'package:flutter_test/flutter_test.dart';
import 'package:loginflow_auth/loginflow_auth_core.dart';

import '../support/auth_fixture.dart';
import '../support/fake_login_flow_server.dart';
import '../support/test_signing_keys.dart';

void main() {
  late TestSigningKeys keys;
  late FakeLoginFlowServer server;

  setUpAll(() => keys = TestSigningKeys.generate());

  setUp(() async => server = await FakeLoginFlowServer.start(keys));

  tearDown(() => server.close());

  group('Web token store (memory only)', () {
    test(
      'a reload loses the session; the silent redirect restores it',
      () async {
        final tab = AuthFixture.create(server);
        await tab.auth.initialize();
        await tab.auth.signInWithBrowser();
        expect(tab.auth.state, isA<SignedIn>());

        final reloaded = AuthFixture.create(server);
        final afterReload = await reloaded.auth.initialize();
        expect(afterReload.data, const SignedOut());

        final silent = await reloaded.auth.signInWithBrowser(
          prompt: AuthorizationPrompt.none,
        );
        expect(silent.data, isA<SignedIn>());
      },
    );

    test('the persisted shape never contains an access token', () async {
      final tab = AuthFixture.create(server);
      await tab.auth.initialize();
      await tab.auth.signInWithPassword(
        loginHint: 'ana@example.com',
        password: 'correct-horse',
      );
      final accessToken = (await tab.auth.accessTokenFor(
        FakeLoginFlowServer.routesApi,
      )).data;

      final stored = (await tab.storedSession())!.toJson();

      expect(stored.keys, isNot(contains('access_token')));
      expect(stored.values, isNot(contains(accessToken)));
    });
  });
}
