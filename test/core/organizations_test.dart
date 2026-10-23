import 'package:flutter_test/flutter_test.dart';
import 'package:loginflow_auth/loginflow_auth_core.dart';

import '../support/auth_fixture.dart';
import '../support/fake_login_flow_server.dart';
import '../support/test_signing_keys.dart';

void main() {
  late TestSigningKeys keys;
  late FakeLoginFlowServer server;

  const north = FakeOrganization(
    id: 'org-north',
    name: 'Transportes Norte',
    externalId: 'client-north',
    permissions: <String, List<String>>{
      FakeLoginFlowServer.routesApi: <String>[
        'rutafacil.drivers.create',
        'rutafacil.drivers.read',
      ],
    },
  );
  const south = FakeOrganization(
    id: 'org-south',
    name: 'Transportes Sur',
    externalId: 'client-south',
    permissions: <String, List<String>>{
      FakeLoginFlowServer.routesApi: <String>['rutafacil.drivers.read'],
    },
  );

  setUpAll(() => keys = TestSigningKeys.generate());

  setUp(() async {
    server = await FakeLoginFlowServer.start(keys);
    server.organizationsBySubject['cu_ana'] = <FakeOrganization>[north, south];
  });

  tearDown(() => server.close());

  Future<AuthFixture> signedIn({String? organization}) async {
    final fixture = AuthFixture.create(server);
    await fixture.auth.initialize();
    await fixture.auth.signInWithPassword(
      loginHint: 'ana@example.com',
      password: 'correct-horse',
      organization: organization,
    );
    return fixture;
  }

  AccessTokenClaims? routesClaims(AuthFixture fixture) =>
      (fixture.auth.state as SignedIn).session.accessClaims[FakeLoginFlowServer
          .routesApi];

  test('a native sign-in opened with an organization starts in it, and the '
      'list names it as active', () async {
    final fixture = await signedIn(organization: south.id);

    final opening = server.challengeRequests.first;
    final listed = await fixture.auth.listOrganizations();

    expect(opening['organization'], south.id);
    expect(
      listed.data,
      const OrganizationList(
        activeOrganizationId: 'org-south',
        organizations: <Organization>[
          Organization(
            id: 'org-north',
            name: 'Transportes Norte',
            kind: OrganizationKind.regular,
            externalId: 'client-north',
          ),
          Organization(
            id: 'org-south',
            name: 'Transportes Sur',
            kind: OrganizationKind.regular,
            externalId: 'client-south',
          ),
        ],
      ),
    );
    expect(listed.data.activeOrganization?.name, 'Transportes Sur');
  });

  test('a hosted sign-in opened with an organization carries it to the '
      'authorization endpoint', () async {
    final fixture = AuthFixture.create(server);
    await fixture.auth.initialize();

    final result = await fixture.auth.signInWithBrowser(organization: north.id);
    await fixture.auth.accessTokenFor(FakeLoginFlowServer.routesApi);

    expect(result.data, isA<SignedIn>());
    expect(
      fixture.browser.openedUrls.last.queryParameters['organization'],
      north.id,
    );
    expect(routesClaims(fixture)?.organizationId, north.id);
  });

  test('switching the organization refreshes with it, drops every cached '
      'API token and the next token is issued for the new one', () async {
    final fixture = await signedIn();
    await fixture.auth.accessTokenFor(FakeLoginFlowServer.routesApi);
    expect(
      routesClaims(fixture),
      const AccessTokenClaims(),
      reason: 'with two organizations and none chosen, none is active',
    );
    expect(
      (await fixture.auth.listOrganizations()).data.activeOrganizationId,
      isNull,
    );

    final switched = await fixture.auth.switchOrganization(north.id);
    final switchRequest = server.tokenRequests.last;
    final claimsAfterSwitch =
        (fixture.auth.state as SignedIn).session.accessClaims;
    final refreshesBefore = server.refreshRequestCount();
    await fixture.auth.accessTokenFor(FakeLoginFlowServer.routesApi);

    expect(switched.isOk, isTrue);
    expect(switchRequest['grant_type'], 'refresh_token');
    expect(switchRequest['organization'], north.id);
    expect(switchRequest.containsKey('resource'), isFalse);
    expect(claimsAfterSwitch, isEmpty);
    expect(
      server.refreshRequestCount(),
      refreshesBefore + 1,
      reason: 'the token cached for the previous organization is not reused',
    );
    expect(
      routesClaims(fixture),
      const AccessTokenClaims(
        organizationId: 'org-north',
        organizationExternalId: 'client-north',
        permissions: <String>[
          'rutafacil.drivers.create',
          'rutafacil.drivers.read',
        ],
      ),
    );
    expect(
      (await fixture.auth.listOrganizations()).data.activeOrganizationId,
      north.id,
    );
    expect((await fixture.storedSession())?.organizationId, north.id);
  });

  test(
    'switching to an organization the user has no assignment in is refused '
    'and keeps the session, its organization and its refresh token',
    () async {
      final fixture = await signedIn(organization: north.id);
      final refreshToken = (await fixture.storedSession())?.refreshToken;

      final switched = await fixture.auth.switchOrganization('org-elsewhere');

      expect(
        switched.errorOrNull,
        const OrganizationUnavailable(organizationId: 'org-elsewhere'),
      );
      expect(fixture.auth.state, isA<SignedIn>());
      expect((await fixture.storedSession())?.refreshToken, refreshToken);
      expect(
        (await fixture.auth.accessTokenFor(FakeLoginFlowServer.routesApi)).isOk,
        isTrue,
      );
      expect(routesClaims(fixture)?.organizationId, north.id);
    },
  );

  test(
    'a step-up opens its authorization in the active organization',
    () async {
      final fixture = await signedIn();
      await fixture.auth.switchOrganization(south.id);

      await fixture.auth.stepUp(
        const StepUpRequirement(acrValues: <String>['mfa']),
      );
      final opening = server.challengeRequests.last;
      await fixture.auth.submitTotp(FakeLoginFlowServer.totpCode);
      await fixture.auth.accessTokenFor(FakeLoginFlowServer.routesApi);

      expect(opening['organization'], south.id);
      expect(routesClaims(fixture)?.organizationId, south.id);
    },
  );
}
