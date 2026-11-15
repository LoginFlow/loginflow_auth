import 'package:flutter_test/flutter_test.dart';
import 'package:loginflow_auth/loginflow_auth_core.dart';
import 'package:loginflow_auth/src/core/jose/compact_jws.dart';

import '../support/auth_fixture.dart';
import '../support/fake_login_flow_server.dart';
import '../support/test_signing_keys.dart';

const String _rootId = 'org-root';
const String _seller = 'role-seller';
const String _beta = 'role-beta';
const String _salesCreate = 'rutafacil.sales.create';

/// The self-selectable roles of a product (`/v1/app/self-selectable-roles`,
/// `doc/server-contract.md` §22), against a fake LoginFlow that applies the
/// server's guard (a DPoP-bound token for LoginFlow itself), its coded
/// refusals and its hourly cap, and that gives the roles taken in the root
/// organization to the next token of the root.
///
/// The client is `app-two`, which has exactly ONE API: its session token's
/// `aud` is that API, so only the token asked with `resource=<issuer>`
/// passes the guard, like the members API.
void main() {
  late TestSigningKeys keys;
  late FakeLoginFlowServer server;

  const north = FakeOrganization(
    id: 'org-north',
    name: 'Transportes Norte',
    externalId: 'client-north',
    permissions: <String, List<String>>{
      FakeLoginFlowServer.routesApi: <String>['rutafacil.drivers.read'],
    },
  );

  setUpAll(() => keys = TestSigningKeys.generate());

  setUp(() async {
    server = await FakeLoginFlowServer.start(keys);
    server.requiresDpop = true;
    server.selfSelectableRoles.addAll(const <FakeSelfSelectableRole>[
      FakeSelfSelectableRole(
        id: _beta,
        key: 'beta',
        name: 'Beta features',
        description: 'Early access',
      ),
      FakeSelfSelectableRole(
        id: _seller,
        key: 'seller',
        name: 'Seller',
        permissions: <String, List<String>>{
          FakeLoginFlowServer.routesApi: <String>[_salesCreate],
        },
      ),
    ]);
    server.unmarkedRoleIds.add('role-admin');
  });

  tearDown(() => server.close());

  Future<AuthFixture> signedIn() async {
    final fixture = AuthFixture.create(
      server,
      clientId: 'app-two',
      enableDpop: true,
    );
    await fixture.auth.initialize();
    await fixture.auth.signInWithPassword(
      loginHint: 'ana@example.com',
      password: 'correct-horse',
    );
    return fixture;
  }

  String audienceOf(String authorization) =>
      CompactJws.parse(authorization.substring(5)).data.claims['aud']!
          as String;

  /// The claims of the routes API token [LoginFlowAuth.accessTokenFor]
  /// hands out now.
  Future<AccessTokenClaims?> routesClaims(AuthFixture fixture) async {
    final token = await fixture.auth.accessTokenFor(
      FakeLoginFlowServer.routesApi,
    );
    expect(token.isOk, isTrue, reason: '$token');
    return (fixture.auth.state as SignedIn)
        .session
        .accessClaims[FakeLoginFlowServer.routesApi];
  }

  // TEST_CHARTER
  // Requirement: the list is a `GET` of the collection, no query, with
  // LoginFlow's own token (`aud` = the issuer) DPoP-bound, and reads the
  // root organization and every role with its held flag.
  // Oracle: the recorded request and the returned `SelfSelectableRoles`.
  // Risk edge: the session token of a single-API client is
  // `403 wrong_audience`, so the screen never loads; a role read without
  // its held flag offers "take" for a role already taken.
  // Layer: integration against the fake LoginFlow (real HTTP, real DPoP).
  // Counterfactual: the session's own token instead of the
  // `resource=<issuer>` one is refused with `wrong_audience`.
  test('the list carries the LoginFlow token, DPoP-bound, and reads the root '
      'and the held flags', () async {
    final fixture = await signedIn();
    await fixture.auth.takeSelfSelectableRole(_seller);

    final listed = await fixture.auth.listSelfSelectableRoles();

    final request = server.selfSelectionRequests.last;
    expect(request.method, 'GET');
    expect(request.uri.path, '/v1/app/self-selectable-roles');
    expect(request.uri.query, isEmpty);
    expect(request.headers['authorization'], startsWith('DPoP '));
    expect(audienceOf(request.headers['authorization']!), server.issuerText);
    expect(request.headers['dpop'], isNotNull);
    expect(
      listed.data,
      const SelfSelectableRoles(
        organization: Organization(
          id: _rootId,
          name: 'RutaFácil',
          kind: OrganizationKind.root,
        ),
        roles: <SelfSelectableRole>[
          SelfSelectableRole(
            id: _beta,
            key: 'beta',
            name: 'Beta features',
            description: 'Early access',
            isHeld: false,
          ),
          SelfSelectableRole(
            id: _seller,
            key: 'seller',
            name: 'Seller',
            isHeld: true,
            assignmentId: 'as_1',
          ),
        ],
      ),
    );
  });

  // TEST_CHARTER
  // Requirement: a take is a body-less `PUT` of the role, DPoP-bound; `201`
  // reads as a new assignment and `200` as already held. After it the
  // session works in the root organization (a switch, since the token was
  // for another one) and drops its API tokens, so the next token of the API
  // carries the role's permissions.
  // Oracle: the recorded request, the returned `SelfSelectedRole`, the
  // `organization` of the refresh, and the `org_id` and `permissions` of the
  // next routes token.
  // Risk edge: the app keeps handing out the cached token of the previous
  // organization, without the permission the person just took, until it
  // expires; or it reads a repeated take as a new one.
  // Layer: integration against the fake LoginFlow.
  // Counterfactual: no refresh after the take keeps `org-north` and no
  // `rutafacil.sales.create` in the next token.
  test('a take is new then already held, and the next token is the root '
      'with the role permissions', () async {
    server.organizationsBySubject['cu_ana'] = <FakeOrganization>[north];
    final fixture = await signedIn();
    final before = await routesClaims(fixture);

    final taken = await fixture.auth.takeSelfSelectableRole(_seller);
    final takeRequest = server.selfSelectionRequests.last;
    final switchRefresh = server.tokenRequests.last;
    final after = await routesClaims(fixture);
    final again = await fixture.auth.takeSelfSelectableRole(_seller);

    expect(before?.organizationId, north.id);
    expect(before?.permissions, isNot(contains(_salesCreate)));
    expect(takeRequest.method, 'PUT');
    expect(takeRequest.uri.path, '/v1/app/self-selectable-roles/$_seller');
    expect(takeRequest.body, isEmpty);
    expect(takeRequest.headers['authorization'], startsWith('DPoP '));
    expect(
      audienceOf(takeRequest.headers['authorization']!),
      server.issuerText,
    );
    expect(takeRequest.headers['dpop'], isNotNull);
    expect(
      taken.data,
      const SelfSelectedRole(
        assignmentId: 'as_1',
        organizationId: _rootId,
        role: MemberRole(id: _seller, key: 'seller', name: 'Seller'),
        isNew: true,
      ),
    );
    expect(switchRefresh['grant_type'], 'refresh_token');
    expect(switchRefresh['organization'], _rootId);
    expect(after?.organizationId, _rootId);
    expect(after?.permissions, contains(_salesCreate));
    expect(again.data, taken.data.copyWith(isNew: false));
  });

  // TEST_CHARTER
  // Requirement: a leave is a `DELETE` of the role, DPoP-bound, answered
  // `204`; after it the session drops its API tokens and refreshes in its
  // organization, so the next token of the API no longer carries the
  // role's permissions.
  // Oracle: the recorded request, the result, and the `permissions` of the
  // next routes token.
  // Risk edge: the app keeps handing out a cached token that still carries
  // the permission the person just left, until it expires.
  // Layer: integration against the fake LoginFlow.
  // Counterfactual: a refresh that keeps the cached API tokens, or no
  // refresh, hands out the token with `rutafacil.sales.create` again.
  test('a leave drops the role permissions from the next token', () async {
    final fixture = await signedIn();
    await fixture.auth.takeSelfSelectableRole(_seller);
    await fixture.auth.switchOrganization(_rootId);
    final held = await routesClaims(fixture);

    final left = await fixture.auth.leaveSelfSelectableRole(_seller);
    final leaveRequest = server.selfSelectionRequests.last;
    final after = await routesClaims(fixture);

    expect(held?.permissions, contains(_salesCreate));
    expect(left.isOk, isTrue, reason: '$left');
    expect(leaveRequest.method, 'DELETE');
    expect(leaveRequest.uri.path, '/v1/app/self-selectable-roles/$_seller');
    expect(leaveRequest.headers['authorization'], startsWith('DPoP '));
    expect(
      audienceOf(leaveRequest.headers['authorization']!),
      server.issuerText,
    );
    expect(leaveRequest.headers['dpop'], isNotNull);
    expect(after?.permissions, isNot(contains(_salesCreate)));
  });

  // TEST_CHARTER
  // Requirement: every refusal of the self-selection rules is
  // `DelegationDenied` with its code and status, and a refused take or
  // leave refreshes nothing.
  // Oracle: the returned errors and the number of refresh requests.
  // Risk edge: every refusal collapses into one opaque "unexpected server
  // response", so the UI cannot say why; or a refusal still rotates the
  // session.
  // Layer: integration against the fake LoginFlow (the API's envelope).
  // Counterfactual: mapping the refusals with the generic account-API error
  // returns `ServerResponseInvalid` and fails every expectation.
  test('refusals are DelegationDenied with the server code', () async {
    final fixture = await signedIn();
    await fixture.auth.listSelfSelectableRoles();
    final refreshes = server.refreshRequestCount();

    final unmarked = await fixture.auth.takeSelfSelectableRole('role-admin');
    server.nextSelfSelectionRefusal = (
      status: 403,
      code: 'organization_out_of_reach',
    );
    final outOfReach = await fixture.auth.takeSelfSelectableRole(_seller);
    server.nextSelfSelectionRefusal = (status: 403, code: 'role_not_grantable');
    final notGrantable = await fixture.auth.leaveSelfSelectableRole(_seller);
    server.nextSelfSelectionRefusal = (status: 409, code: 'member_inactive');
    final inactive = await fixture.auth.takeSelfSelectableRole(_seller);
    final notHeld = await fixture.auth.leaveSelfSelectableRole(_beta);

    expect(
      unmarked.errorOrNull,
      const DelegationDenied(
        code: DelegationDenialCode.selfAssignmentForbidden,
        statusCode: 403,
      ),
    );
    expect(
      outOfReach.errorOrNull,
      const DelegationDenied(
        code: DelegationDenialCode.organizationOutOfReach,
        statusCode: 403,
      ),
    );
    expect(
      notGrantable.errorOrNull,
      const DelegationDenied(
        code: DelegationDenialCode.roleNotGrantable,
        statusCode: 403,
      ),
    );
    expect(
      inactive.errorOrNull,
      const DelegationDenied(
        code: DelegationDenialCode.memberInactive,
        statusCode: 409,
      ),
    );
    expect(
      notHeld.errorOrNull,
      const DelegationDenied(
        code: DelegationDenialCode.assignmentNotFound,
        statusCode: 404,
      ),
    );
    expect(server.refreshRequestCount(), refreshes);
  });

  // TEST_CHARTER
  // Requirement: past 10 takes and leaves in the hour,
  // `429 self_selection_rate_limited` is `RateLimited` with the
  // `Retry-After` the server sent.
  // Oracle: the returned error and its `retryAfter`.
  // Risk edge: the UI cannot tell the person how long to wait.
  // Layer: integration against the fake LoginFlow.
  // Counterfactual: reading the `429` as a delegation refusal or ignoring
  // `Retry-After` fails the expectation.
  test('past the hourly cap a take is RateLimited with Retry-After', () async {
    final fixture = await signedIn();
    for (
      var change = 0;
      change < FakeLoginFlowServer.selfSelectionCap;
      change += 2
    ) {
      await fixture.auth.takeSelfSelectableRole(_seller);
      await fixture.auth.leaveSelfSelectableRole(_seller);
    }

    final limited = await fixture.auth.takeSelfSelectableRole(_seller);

    expect(
      limited.errorOrNull,
      const RateLimited(
        retryAfter: FakeLoginFlowServer.selfSelectionRetryAfter,
      ),
    );
  });
}
