import 'dart:async';

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

  /// The `permissions` claim of [token], decoded without verification.
  List<Object?> permissionsOf(String token) =>
      CompactJws.parse(token).data.claims['permissions']! as List<Object?>;

  /// The permissions of the routes API token [LoginFlowAuth.accessTokenFor]
  /// hands out now, read from the token itself: the published claims can
  /// lag behind the cache, and a missing entry would pass any "does not
  /// contain" check.
  Future<List<Object?>> routesPermissions(AuthFixture fixture) async {
    final token = await fixture.auth.accessTokenFor(
      FakeLoginFlowServer.routesApi,
    );
    expect(token.isOk, isTrue, reason: '$token');
    return permissionsOf(token.data);
  }

  /// The routes permissions the session publishes now
  /// (`session.accessClaims`), empty when it publishes none for that API.
  List<String> publishedRoutesPermissions(AuthFixture fixture) =>
      (fixture.auth.state as SignedIn)
          .session
          .accessClaims[FakeLoginFlowServer.routesApi]
          ?.permissions ??
      const <String>[];

  Future<void> untilRefreshCount(int count) async {
    while (server.refreshRequestCount() < count) {
      await Future<void>.delayed(const Duration(milliseconds: 1));
    }
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
  // role's permissions. (The take already moved the session to the root.)
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
    final held = await routesPermissions(fixture);

    final left = await fixture.auth.leaveSelfSelectableRole(_seller);
    final leaveRequest = server.selfSelectionRequests.last;
    final after = await routesPermissions(fixture);

    expect(held, contains(_salesCreate));
    expect(left.isOk, isTrue, reason: '$left');
    expect(leaveRequest.method, 'DELETE');
    expect(leaveRequest.uri.path, '/v1/app/self-selectable-roles/$_seller');
    expect(leaveRequest.headers['authorization'], startsWith('DPoP '));
    expect(
      audienceOf(leaveRequest.headers['authorization']!),
      server.issuerText,
    );
    expect(leaveRequest.headers['dpop'], isNotNull);
    expect(after, isNot(contains(_salesCreate)));
  });

  // TEST_CHARTER
  // Requirement: every refusal of the self-selection rules, on the list, a
  // take or a leave, is `DelegationDenied` with its code and status, and a
  // refused take or leave refreshes nothing.
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
    server.nextSelfSelectionRefusal = (
      status: 404,
      code: 'organization_not_found',
    );
    final noRoot = await fixture.auth.listSelfSelectableRoles();

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
    expect(
      noRoot.errorOrNull,
      const DelegationDenied(
        code: DelegationDenialCode.organizationNotFound,
        statusCode: 404,
      ),
    );
    expect(server.refreshRequestCount(), refreshes);
  });

  // TEST_CHARTER
  // Requirement: a leave fails closed. Once the `DELETE` answers `204` the
  // cached API tokens are gone, whatever the refresh after it does: while
  // the token endpoint is down `accessTokenFor` fails, and once it is back
  // it hands out a token without the role. The leave itself is `Ok`.
  // Oracle: the leave's result, the `accessTokenFor` result and the
  // published `accessClaims` while the token endpoint answers `503`, and the
  // `permissions` of the next routes token.
  // Risk edge: the refresh after the leave fails and the app keeps handing
  // out the cached token that carries the permission just left, for up to
  // its lifetime.
  // Layer: integration against the fake LoginFlow (a real `503` from the
  // token endpoint).
  // Counterfactual: dropping the API tokens only when the refresh succeeds
  // hands out the cached token with `rutafacil.sales.create`, with no
  // refresh at all.
  test(
    'a leave whose refresh fails never hands out the left permission',
    () async {
      final fixture = await signedIn();
      await fixture.auth.takeSelfSelectableRole(_seller);
      final held = await routesPermissions(fixture);
      // The LoginFlow token the leave presents, so that the only refreshes
      // that fail are the ones after the leave.
      await fixture.auth.listSelfSelectableRoles();
      final publishedHeld = publishedRoutesPermissions(fixture);
      server.failingRefreshes = 2;

      final left = await fixture.auth.leaveSelfSelectableRole(_seller);
      final whileDown = await fixture.auth.accessTokenFor(
        FakeLoginFlowServer.routesApi,
      );
      final publishedWhileDown = publishedRoutesPermissions(fixture);
      final afterwards = await routesPermissions(fixture);

      expect(held, contains(_salesCreate));
      expect(publishedHeld, contains(_salesCreate));
      expect(publishedWhileDown, isNot(contains(_salesCreate)));
      expect(left.isOk, isTrue, reason: '$left');
      expect(whileDown.isOk, isFalse, reason: '$whileDown');
      expect(afterwards, isNot(contains(_salesCreate)));
      expect(fixture.auth.state, isA<SignedIn>());
    },
  );

  // TEST_CHARTER
  // Requirement: a token asked for after a leave never joins a refresh of
  // that API which started before it: that refresh was answered while the
  // role was still held.
  // Oracle: the `permissions` of the token handed to the call made after
  // the leave's `204`, against the one handed to the call made before.
  // Risk edge: the call after the leave shares the earlier refresh's
  // answer and gets the left permission for the token's whole lifetime.
  // Layer: integration against the fake LoginFlow, with the earlier refresh
  // held back by the server.
  // Counterfactual: without clearing the refreshes in flight at the leave,
  // the later call joins the earlier one and gets `rutafacil.sales.create`.
  test('a token asked after a leave never joins a refresh that started '
      'before it', () async {
    final fixture = await signedIn();
    await fixture.auth.takeSelfSelectableRole(_seller);
    await routesClaims(fixture);
    await fixture.auth.listSelfSelectableRoles();
    fixture.auth.discardAccessToken(FakeLoginFlowServer.routesApi);
    final gate = Completer<void>();
    server.refreshResponseGate = gate;
    final refreshes = server.refreshRequestCount();
    final before = fixture.auth.accessTokenFor(FakeLoginFlowServer.routesApi);
    await untilRefreshCount(refreshes + 1);
    final requests = server.selfSelectionRequests.length;

    final leaving = fixture.auth.leaveSelfSelectableRole(_seller);
    while (server.selfSelectionRequests.length == requests) {
      await Future<void>.delayed(const Duration(milliseconds: 1));
    }
    await pumpEventQueue();
    final after = fixture.auth.accessTokenFor(FakeLoginFlowServer.routesApi);
    gate.complete();
    final beforeToken = await before;
    final left = await leaving;
    final afterToken = await after;

    expect(left.isOk, isTrue, reason: '$left');
    expect(permissionsOf(beforeToken.data), contains(_salesCreate));
    expect(permissionsOf(afterToken.data), isNot(contains(_salesCreate)));
  });

  // TEST_CHARTER
  // Requirement: a refresh of an API that was in flight at the leave, and
  // answered while the role was still held, does not put its token back in
  // the cache when it completes.
  // Oracle: the `permissions` of the routes token handed out after the
  // leave returns.
  // Risk edge: the late refresh writes back the left permission after the
  // drop, and every later call gets it for the token's whole lifetime.
  // Layer: integration against the fake LoginFlow, with the earlier refresh
  // held back by the server until after the leave's `204`.
  // Counterfactual: dropping the API tokens only once, at the `204`, keeps
  // the late token with `rutafacil.sales.create`.
  test(
    'a refresh in flight at the leave does not put its token back',
    () async {
      final fixture = await signedIn();
      await fixture.auth.takeSelfSelectableRole(_seller);
      await routesClaims(fixture);
      await fixture.auth.listSelfSelectableRoles();
      fixture.auth.discardAccessToken(FakeLoginFlowServer.routesApi);
      final gate = Completer<void>();
      server.refreshResponseGate = gate;
      final refreshes = server.refreshRequestCount();
      final before = fixture.auth.accessTokenFor(FakeLoginFlowServer.routesApi);
      await untilRefreshCount(refreshes + 1);
      final requests = server.selfSelectionRequests.length;

      final leaving = fixture.auth.leaveSelfSelectableRole(_seller);
      while (server.selfSelectionRequests.length == requests) {
        await Future<void>.delayed(const Duration(milliseconds: 1));
      }
      await pumpEventQueue();
      gate.complete();
      final beforeToken = await before;
      final left = await leaving;
      final afterwards = await routesPermissions(fixture);

      expect(left.isOk, isTrue, reason: '$left');
      expect(permissionsOf(beforeToken.data), contains(_salesCreate));
      expect(afterwards, isNot(contains(_salesCreate)));
    },
  );

  // TEST_CHARTER
  // Requirement: when the server ended this app's refresh family at the
  // leave (its client no longer admits the person), the leave is still
  // `Ok` and the refresh after it signs out with `sessionRevoked`.
  // Oracle: the leave's result and the state afterwards.
  // Risk edge: the app reports a failed leave that did happen, or keeps a
  // session the server already ended.
  // Layer: integration against the fake LoginFlow (`invalid_grant` on the
  // refresh).
  // Counterfactual: no refresh after the leave keeps the state `SignedIn`;
  // returning the refresh failure makes the leave an error.
  test('a leave whose session the server ended is Ok and signs out', () async {
    final fixture = await signedIn();
    await fixture.auth.takeSelfSelectableRole(_seller);
    await fixture.auth.listSelfSelectableRoles();
    server.rejectNextRefresh = true;

    final left = await fixture.auth.leaveSelfSelectableRole(_seller);

    expect(left.isOk, isTrue, reason: '$left');
    expect(
      fixture.auth.state,
      const SignedOut(reason: SignOutReason.sessionRevoked),
    );
  });

  // TEST_CHARTER
  // Requirement: a take whose switch to the root fails is still `Ok` (the
  // role is held on the server) and the session stays signed in.
  // Oracle: the take's result and the state afterwards.
  // Risk edge: the app reports a failed take that did happen, or drops the
  // session over a transient token endpoint failure.
  // Layer: integration against the fake LoginFlow (a real `503` from the
  // token endpoint).
  // Counterfactual: returning the switch failure makes the take an error.
  test('a take whose switch fails is Ok and stays signed in', () async {
    final fixture = await signedIn();
    await fixture.auth.listSelfSelectableRoles();
    server.failingRefreshes = 1;

    final taken = await fixture.auth.takeSelfSelectableRole(_seller);

    expect(taken.isOk, isTrue, reason: '$taken');
    expect(taken.data.isNew, isTrue);
    expect(fixture.auth.state, isA<SignedIn>());
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
