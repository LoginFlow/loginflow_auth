import 'package:flutter_test/flutter_test.dart';
import 'package:loginflow_auth/loginflow_auth_core.dart';
import 'package:loginflow_auth/src/core/jose/compact_jws.dart';

import '../support/auth_fixture.dart';
import '../support/fake_login_flow_server.dart';
import '../support/test_signing_keys.dart';

void main() {
  late TestSigningKeys keys;
  late FakeLoginFlowServer server;

  setUpAll(() => keys = TestSigningKeys.generate());

  setUp(() async => server = await FakeLoginFlowServer.start(keys));

  tearDown(() => server.close());

  Future<AuthFixture> signedIn({
    String clientId = 'app-one',
    bool enableDpop = false,
  }) async {
    final fixture = AuthFixture.create(
      server,
      clientId: clientId,
      enableDpop: enableDpop,
    );
    await fixture.auth.initialize();
    await fixture.auth.signInWithPassword(
      loginHint: 'ana@example.com',
      password: 'correct-horse',
    );
    return fixture;
  }

  String audienceOf(String accessToken) =>
      CompactJws.parse(accessToken).data.claims['aud']! as String;

  test('a token for an API is asked with resource on the refresh, carries '
      'that audience and is reused while fresh', () async {
    final fixture = await signedIn();

    final first = await fixture.auth.accessTokenFor(
      FakeLoginFlowServer.routesApi,
    );
    final request = server.tokenRequests.last;
    final requestsAfterFirst = server.tokenRequestCount;
    final second = await fixture.auth.accessTokenFor(
      FakeLoginFlowServer.routesApi,
    );

    expect(request['grant_type'], 'refresh_token');
    expect(request['resource'], FakeLoginFlowServer.routesApi);
    expect(audienceOf(first.data), FakeLoginFlowServer.routesApi);
    expect(second.data, first.data);
    expect(server.tokenRequestCount, requestsAfterFirst);
  });

  test('each API gets its own token on the same session and DPoP key, '
      'and its headers carry that token', () async {
    server.requiresDpop = true;
    final fixture = await signedIn(enableDpop: true);
    final api = server.issuer.replace(
      path: FakeLoginFlowServer.userProfilePath,
    );

    final routes = await fixture.auth.accessTokenFor(
      FakeLoginFlowServer.routesApi,
    );
    final reports = await fixture.auth.accessTokenFor(
      FakeLoginFlowServer.reportsApi,
    );
    final headers = await fixture.auth.authorizedHeadersFor(
      FakeLoginFlowServer.reportsApi,
      method: 'GET',
      uri: api,
    );

    expect(audienceOf(routes.data), FakeLoginFlowServer.routesApi);
    expect(audienceOf(reports.data), FakeLoginFlowServer.reportsApi);
    expect(
      server.tokenRequests
          .where((request) => request['grant_type'] == 'refresh_token')
          .map((request) => request['resource']),
      <String>[FakeLoginFlowServer.routesApi, FakeLoginFlowServer.reportsApi],
    );
    expect(server.acceptedDpopThumbprints.toSet(), hasLength(1));
    expect(headers.data.authorization, 'DPoP ${reports.data}');
    expect(headers.data.dpopProof, isNotNull);
    expect(fixture.auth.state, isA<SignedIn>());
  });

  test('an expired API token is refreshed again with its resource', () async {
    final fixture = await signedIn();
    final first = await fixture.auth.accessTokenFor(
      FakeLoginFlowServer.routesApi,
    );
    fixture.clock.advance(const Duration(minutes: 15));

    final renewed = await fixture.auth.accessTokenFor(
      FakeLoginFlowServer.routesApi,
    );

    expect(renewed.data, isNot(first.data));
    expect(server.refreshRequestCount(), 2);
    expect(
      server.tokenRequests.last['resource'],
      FakeLoginFlowServer.routesApi,
    );
  });

  test('concurrent requests for two APIs share one refresh per API and '
      'never present the same refresh token twice', () async {
    final fixture = await signedIn();

    final tokens = await Future.wait(<Future<Result<String, LoginFlowError>>>[
      fixture.auth.accessTokenFor(FakeLoginFlowServer.routesApi),
      fixture.auth.accessTokenFor(FakeLoginFlowServer.reportsApi),
      fixture.auth.accessTokenFor(FakeLoginFlowServer.routesApi),
    ]);
    final presented = server.tokenRequests
        .where((request) => request['grant_type'] == 'refresh_token')
        .map((request) => request['refresh_token'])
        .toList();

    expect(tokens.every((token) => token.isOk), isTrue);
    expect(tokens[0].data, tokens[2].data);
    expect(presented, hasLength(2));
    expect(presented.toSet(), hasLength(2));
    expect(fixture.auth.state, isA<SignedIn>());
  });

  test('an API the server does not issue to this client is InvalidTarget '
      'and the session survives', () async {
    final fixture = await signedIn(clientId: 'app-two');

    final refused = await fixture.auth.accessTokenFor(
      FakeLoginFlowServer.reportsApi,
    );

    expect(
      server.tokenRequests.last['resource'],
      FakeLoginFlowServer.reportsApi,
    );
    expect(
      refused.errorOrNull,
      const InvalidTarget(api: FakeLoginFlowServer.reportsApi),
    );
    expect(fixture.auth.state, isA<SignedIn>());
    expect(
      (await fixture.auth.accessTokenFor(FakeLoginFlowServer.routesApi)).isOk,
      isTrue,
    );
  });

  test('an API missing from LoginFlowConfig.apis is refused before any '
      'request', () async {
    final fixture = await signedIn();
    final requests = server.tokenRequestCount;

    final refused = await fixture.auth.accessTokenFor('API-UNDECLARED');

    expect(refused.errorOrNull, isA<ConfigurationInvalid>());
    expect(server.tokenRequestCount, requests);
  });
}
