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

  group('AccessTokenClaims.decode (UI only, unverified)', () {
    test('reads the organization and the listed permissions', () {
      final token = keys.sign(<String, Object?>{
        'sub': 'cu_ana',
        'aud': FakeLoginFlowServer.routesApi,
        'org_id': 'org-north',
        'org_ext': 'client-north',
        'permissions': <String>['rutafacil.drivers.read'],
      }, type: 'at+jwt');

      expect(
        AccessTokenClaims.decode(token),
        const AccessTokenClaims(
          organizationId: 'org-north',
          organizationExternalId: 'client-north',
          permissions: <String>['rutafacil.drivers.read'],
        ),
      );
    });

    test('an overage token has no permissions and says so', () {
      final token = keys.sign(<String, Object?>{
        'sub': 'cu_ana',
        'org_id': 'org-north',
        'permissions_overage': true,
      }, type: 'at+jwt');

      expect(
        AccessTokenClaims.decode(token),
        const AccessTokenClaims(
          organizationId: 'org-north',
          isPermissionsOverage: true,
        ),
      );
    });

    test('an opaque token has no claims', () {
      expect(AccessTokenClaims.decode('at_opaque-token'), isNull);
    });

    test('round-trips through JSON', () {
      const claims = AccessTokenClaims(
        organizationId: 'org-north',
        permissions: <String>['rutafacil.drivers.read'],
      );

      expect(AccessTokenClaims.fromJson(claims.toJson()), claims);
    });
  });

  group('LoginFlowSession.accessClaims', () {
    Future<AuthFixture> signedIn() async {
      final fixture = AuthFixture.create(server);
      await fixture.auth.initialize();
      await fixture.auth.signInWithPassword(
        loginHint: 'ana@example.com',
        password: 'correct-horse',
      );
      return fixture;
    }

    Map<String, AccessTokenClaims> claimsOf(AuthFixture fixture) =>
        (fixture.auth.state as SignedIn).session.accessClaims;

    test('holds, per API, only that API\'s permissions in the active '
        'organization', () async {
      server.organizationsBySubject['cu_ana'] = const <FakeOrganization>[
        FakeOrganization(
          id: 'org-north',
          name: 'Transportes Norte',
          externalId: 'client-north',
          permissions: <String, List<String>>{
            FakeLoginFlowServer.routesApi: <String>['rutafacil.drivers.read'],
            FakeLoginFlowServer.reportsApi: <String>['rutafacil.reports.read'],
          },
        ),
      ];
      final fixture = await signedIn();

      await fixture.auth.accessTokenFor(FakeLoginFlowServer.routesApi);
      final afterRoutes = claimsOf(fixture);
      await fixture.auth.accessTokenFor(FakeLoginFlowServer.reportsApi);

      expect(afterRoutes.keys, <String>[FakeLoginFlowServer.routesApi]);
      expect(claimsOf(fixture), <String, AccessTokenClaims>{
        FakeLoginFlowServer.routesApi: const AccessTokenClaims(
          organizationId: 'org-north',
          organizationExternalId: 'client-north',
          permissions: <String>['rutafacil.drivers.read'],
        ),
        FakeLoginFlowServer.reportsApi: const AccessTokenClaims(
          organizationId: 'org-north',
          organizationExternalId: 'client-north',
          permissions: <String>['rutafacil.reports.read'],
        ),
      });
    });

    test('reports an overage when the permissions do not fit in the '
        'token', () async {
      server.organizationsBySubject['cu_ana'] = <FakeOrganization>[
        FakeOrganization(
          id: 'org-north',
          name: 'Transportes Norte',
          permissions: <String, List<String>>{
            FakeLoginFlowServer.routesApi: <String>[
              for (
                var index = 0;
                index <= FakeLoginFlowServer.maxTokenPermissions;
                index++
              )
                'rutafacil.resource$index.read',
            ],
          },
        ),
      ];
      final fixture = await signedIn();

      await fixture.auth.accessTokenFor(FakeLoginFlowServer.routesApi);

      expect(
        claimsOf(fixture)[FakeLoginFlowServer.routesApi],
        const AccessTokenClaims(
          organizationId: 'org-north',
          isPermissionsOverage: true,
        ),
      );
    });
  });
}
