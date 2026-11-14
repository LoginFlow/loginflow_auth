import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:loginflow_auth/loginflow_auth_core.dart';

import '../support/auth_fixture.dart';
import '../support/fake_login_flow_server.dart';
import '../support/test_signing_keys.dart';

/// An API refused the token itself: the app discards it and the library asks
/// LoginFlow for a new one instead of handing back the refused token.
void main() {
  late TestSigningKeys keys;
  late FakeLoginFlowServer server;

  setUpAll(() => keys = TestSigningKeys.generate());

  setUp(() async => server = await FakeLoginFlowServer.start(keys));

  tearDown(() => server.close());

  Future<AuthFixture> signedIn() async {
    final fixture = AuthFixture.create(server);
    await fixture.auth.initialize();
    await fixture.auth.signInWithPassword(
      loginHint: 'ana@example.com',
      password: 'correct-horse',
    );
    return fixture;
  }

  Future<void> untilRefreshCount(int count) async {
    while (server.refreshRequestCount() < count) {
      await Future<void>.delayed(const Duration(milliseconds: 1));
    }
  }

  test('the next token for a discarded API is a new one, asked with its '
      'resource; another API keeps its token', () async {
    final fixture = await signedIn();
    final routes = await fixture.auth.accessTokenFor(
      FakeLoginFlowServer.routesApi,
    );
    final reports = await fixture.auth.accessTokenFor(
      FakeLoginFlowServer.reportsApi,
    );
    final refreshes = server.refreshRequestCount();

    final discarded = await fixture.auth.discardAccessToken(
      FakeLoginFlowServer.routesApi,
    );
    final renewed = await fixture.auth.accessTokenFor(
      FakeLoginFlowServer.routesApi,
    );
    final reportsAgain = await fixture.auth.accessTokenFor(
      FakeLoginFlowServer.reportsApi,
    );

    expect(discarded.isOk, isTrue);
    expect(renewed.data, isNot(routes.data));
    expect(server.refreshRequestCount(), refreshes + 1);
    expect(
      server.tokenRequests.last['resource'],
      FakeLoginFlowServer.routesApi,
    );
    expect(reportsAgain.data, reports.data);
    expect(fixture.auth.state, isA<SignedIn>());
  });

  test('after a discard, a session LoginFlow ended is SessionRevoked and '
      'signs out', () async {
    final fixture = await signedIn();
    final routes = await fixture.auth.accessTokenFor(
      FakeLoginFlowServer.routesApi,
    );
    server.rejectNextRefresh = true;

    await fixture.auth.discardAccessToken(FakeLoginFlowServer.routesApi);
    final next = await fixture.auth.authorizedHeadersFor(
      FakeLoginFlowServer.routesApi,
      method: 'POST',
      uri: server.issuer.replace(path: '/session'),
    );

    expect(routes.isOk, isTrue);
    expect(next.errorOrNull, const SessionRevoked());
    expect(
      fixture.auth.state,
      const SignedOut(reason: SignOutReason.sessionRevoked),
    );
  });

  test('a discard made while another API refreshes is not undone when that '
      'refresh completes', () async {
    final fixture = await signedIn();
    final routes = await fixture.auth.accessTokenFor(
      FakeLoginFlowServer.routesApi,
    );
    final gate = Completer<void>();
    server.refreshResponseGate = gate;
    final refreshes = server.refreshRequestCount();
    final reports = fixture.auth.accessTokenFor(FakeLoginFlowServer.reportsApi);
    await untilRefreshCount(refreshes + 1);

    final discarding = fixture.auth.discardAccessToken(
      FakeLoginFlowServer.routesApi,
    );
    gate.complete();
    await reports;
    await discarding;
    server.refreshResponseGate = null;
    final renewed = await fixture.auth.accessTokenFor(
      FakeLoginFlowServer.routesApi,
    );

    expect(renewed.isOk, isTrue);
    expect(renewed.data, isNot(routes.data));
  });

  test('a token asked right after a discard, not awaited and while another '
      'API refreshes, is a new one', () async {
    final fixture = await signedIn();
    final routes = await fixture.auth.accessTokenFor(
      FakeLoginFlowServer.routesApi,
    );
    final gate = Completer<void>();
    server.refreshResponseGate = gate;
    final refreshes = server.refreshRequestCount();
    final reports = fixture.auth.accessTokenFor(FakeLoginFlowServer.reportsApi);
    await untilRefreshCount(refreshes + 1);

    final discarding = fixture.auth.discardAccessToken(
      FakeLoginFlowServer.routesApi,
    );
    final renewing = fixture.auth.accessTokenFor(FakeLoginFlowServer.routesApi);
    gate.complete();
    await reports;
    await discarding;
    final renewed = await renewing;

    expect(renewed.isOk, isTrue);
    expect(renewed.data, isNot(routes.data));
  });

  test('an API missing from LoginFlowConfig.apis is refused before any '
      'request', () async {
    final fixture = await signedIn();
    final requests = server.tokenRequestCount;

    final refused = await fixture.auth.discardAccessToken('API-UNDECLARED');

    expect(refused.errorOrNull, isA<ConfigurationInvalid>());
    expect(server.tokenRequestCount, requests);
  });
}
