import 'package:flutter_test/flutter_test.dart';
import 'package:loginflow_auth/loginflow_auth_core.dart';

import '../support/auth_fixture.dart';
import '../support/fake_login_flow_server.dart';
import '../support/test_dpop_key_store.dart';
import '../support/test_signing_keys.dart';

/// A persisted, DPoP-bound session (the web profile: refresh token in
/// browser storage, non-extractable key in IndexedDB) restored by a new
/// [LoginFlowAuth] over the same store — a page reload or a second tab.
void main() {
  late TestSigningKeys keys;
  late FakeLoginFlowServer server;

  setUpAll(() => keys = TestSigningKeys.generate());

  setUp(() async {
    server = await FakeLoginFlowServer.start(keys)
      ..requiresDpop = true;
  });

  tearDown(() => server.close());

  AuthFixture page(SessionStore store, {int keySeed = 1}) => AuthFixture.create(
    server,
    sessionStore: store,
    enableDpop: true,
    dpopKeyStore: TestDpopKeyStore(seed: keySeed),
  );

  Future<SessionStore> signedInStore() async {
    final store = InMemorySessionStore();
    final first = page(store);
    await first.auth.initialize();
    await first.auth.signInWithPassword(
      loginHint: 'ana@example.com',
      password: 'correct-horse',
    );
    return store;
  }

  test(
    'a reload with the same key restores the session by refreshing it',
    () async {
      final store = await signedInStore();
      final refreshesBefore = server.refreshRequestCount();

      final reloaded = page(store);
      final started = await reloaded.auth.initialize();

      expect(started.data, isA<SignedIn>());
      expect(server.refreshRequestCount(), refreshesBefore + 1);
      expect(server.acceptedDpopThumbprints.toSet(), hasLength(1));
    },
  );

  test('a reload without the bound key ends the session locally', () async {
    final store = await signedInStore();
    final refreshesBefore = server.refreshRequestCount();

    final reloaded = page(store, keySeed: 2);
    final started = await reloaded.auth.initialize();

    expect(
      started.data,
      isA<SignedOut>().having(
        (state) => state.reason,
        'reason',
        SignOutReason.sessionRevoked,
      ),
    );
    expect(server.refreshRequestCount(), refreshesBefore);
    expect(await reloaded.storedSession(), isNull);
  });

  test('two tabs sharing the stored session keep rotating it without '
      'presenting an already-used refresh token', () async {
    final store = await signedInStore();
    final firstTab = page(store);
    final secondTab = page(store);
    await firstTab.auth.initialize();
    await secondTab.auth.initialize();

    firstTab.clock.advance(const Duration(minutes: 15));
    final firstTabToken = await firstTab.auth.accessTokenFor(
      FakeLoginFlowServer.routesApi,
    );
    secondTab.clock.advance(const Duration(minutes: 15));
    final secondTabToken = await secondTab.auth.accessTokenFor(
      FakeLoginFlowServer.routesApi,
    );

    expect(firstTabToken.isOk, isTrue);
    expect(secondTabToken.isOk, isTrue);
    expect(firstTab.auth.state, isA<SignedIn>());
    expect(secondTab.auth.state, isA<SignedIn>());
  });
}
