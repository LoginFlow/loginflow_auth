import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:loginflow_auth/loginflow_auth_core.dart';

import '../support/auth_fixture.dart';
import '../support/fake_login_flow_server.dart';
import '../support/test_signing_keys.dart';

void main() {
  late TestSigningKeys keys;
  late FakeLoginFlowServer server;

  setUpAll(() => keys = TestSigningKeys.generate());

  setUp(() async {
    server = await FakeLoginFlowServer.start(keys)
      ..requiresDpop = true;
  });

  tearDown(() => server.close());

  Future<http.Response> fetchProfile(LoginFlowAuth auth, Uri uri) async {
    final authorization = await auth.authorizedHeadersFor(
      FakeLoginFlowServer.routesApi,
      method: 'GET',
      uri: uri,
    );
    return http.get(uri, headers: authorization.data.toHeaders());
  }

  test('an app calls its own DPoP-protected API with the library headers, '
      'retrying once on a use_dpop_nonce challenge', () async {
    final fixture = AuthFixture.create(server, enableDpop: true);
    await fixture.auth.initialize();
    await fixture.auth.signInWithPassword(
      loginHint: 'ana@example.com',
      password: 'correct-horse',
    );
    final uri = server.issuer.replace(
      path: FakeLoginFlowServer.userProfilePath,
      queryParameters: <String, String>{'expand': 'company'},
    );
    // The API token is obtained first, so the nonce challenge below lands
    // on the resource request and not on the refresh that issues it.
    await fixture.auth.accessTokenFor(FakeLoginFlowServer.routesApi);
    server.nextDpopNonceChallenge = 'resource-nonce-1';

    final challenged = await fetchProfile(fixture.auth, uri);
    final shouldRetry = fixture.auth.shouldRetryResourceRequest(
      uri: uri,
      statusCode: challenged.statusCode,
      dpopNonce: challenged.headers['dpop-nonce'],
      wwwAuthenticate: challenged.headers['www-authenticate'],
    );
    final retried = await fetchProfile(fixture.auth, uri);

    expect(challenged.statusCode, 401);
    expect(shouldRetry, isTrue);
    expect(retried.statusCode, 200);
    expect((jsonDecode(retried.body) as Map<String, Object?>)['sub'], 'cu_ana');
  });
}
