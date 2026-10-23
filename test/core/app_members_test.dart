import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:loginflow_auth/loginflow_auth_core.dart';
import 'package:loginflow_auth/src/core/jose/compact_jws.dart';

import '../support/auth_fixture.dart';
import '../support/fake_login_flow_server.dart';
import '../support/test_signing_keys.dart';

const String _clientOrg = 'org-client-7';

/// The members API of a product's "Team" screen (`/v1/app/members`,
/// `doc/server-contract.md` §18), against a fake LoginFlow that applies the
/// server's guard: a DPoP-bound token for LoginFlow itself (`aud` = the
/// issuer), a recent sign-in on every write, and coded refusals.
///
/// The client is `app-two`, which has exactly ONE API: its session token's
/// `aud` is that API, like a product with a single backend (RutaFácil), so
/// only a token asked with `resource=<issuer>` passes the guard.
void main() {
  late TestSigningKeys keys;
  late FakeLoginFlowServer server;

  setUpAll(() => keys = TestSigningKeys.generate());

  setUp(() async {
    server = await FakeLoginFlowServer.start(keys);
    server.requiresDpop = true;
    server.membersOrganizations[_clientOrg] = const FakeMembersOrganization(
      id: _clientOrg,
      name: 'Transportes Norte',
      grantableRoles: <Map<String, Object?>>[
        <String, Object?>{
          'id': 'role-client-admin',
          'key': 'client_admin',
          'name': 'Admin de cliente',
          'description': null,
          'max_expires_at': null,
        },
      ],
      members: <Map<String, Object?>>[
        <String, Object?>{
          'principal_id': 'cu_tomas',
          'email': 'tomas@example.com',
          'name': 'Tomás Gil',
          'assignments': <Object?>[
            <String, Object?>{
              'id': 'as-existing',
              'role': <String, Object?>{
                'id': 'role-client-admin',
                'key': 'client_admin',
                'name': 'Admin de cliente',
              },
              'expires_at': '2026-12-31T00:00:00',
              'manageable': true,
            },
          ],
        },
      ],
    );
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

  String audienceOf(String accessToken) =>
      CompactJws.parse(accessToken).data.claims['aud']! as String;

  // TEST_CHARTER
  // Requirement: every members call carries LoginFlow's own token (`aud` =
  // the issuer), asked once with `resource=<issuer>` on the session's
  // refresh family and then reused, DPoP-bound with a proof per request.
  // Oracle: the refresh request's `resource`, the `aud` and scheme of the
  // token each members request presents, its DPoP proof, and the parsed
  // grantable roles.
  // Risk edge: the session token of a single-API client is that API's token;
  // presenting it is `403 wrong_audience` (the guard against a product
  // backend replaying a token at LoginFlow), so the "Team" screen never
  // loads.
  // Layer: integration against the fake LoginFlow (real HTTP, real DPoP).
  // Counterfactual: using the session's own token instead of the
  // `resource=<issuer>` one fails on `wrong_audience`.
  test('members calls carry the LoginFlow token asked with resource=<issuer>, '
      'DPoP-bound, reused while fresh', () async {
    final fixture = await signedIn();

    final roles = await fixture.auth.listGrantableRoles(
      organizationId: _clientOrg,
    );
    final refreshes = server.refreshRequestCount();
    final page = await fixture.auth.listMembers(organizationId: _clientOrg);

    expect(roles.isOk, isTrue, reason: '$roles');
    expect(roles.data.organization.name, 'Transportes Norte');
    expect(roles.data.roles.single.key, 'client_admin');
    expect(page.data.items.single.identity.email, 'tomas@example.com');
    expect(
      page.data.items.single.assignments.single.expiresAt,
      DateTime.utc(2026, 12, 31),
    );
    expect(server.tokenRequests.last['resource'], server.issuerText);
    expect(server.refreshRequestCount(), refreshes);
    for (final request in server.membersRequests) {
      final authorization = request.headers['authorization']!;
      expect(authorization, startsWith('DPoP '));
      expect(audienceOf(authorization.substring(5)), server.issuerText);
      expect(request.headers['dpop'], isNotNull);
    }
    expect(server.membersRequests.last.uri.queryParameters, <String, String>{
      'organization_id': _clientOrg,
      'limit': '50',
      'offset': '0',
    });
  });

  // TEST_CHARTER
  // Requirement: invite, grant and revoke send exactly the contract's
  // bodies and paths (the server refuses unknown fields), with `expires_at`
  // as an RFC 3339 instant in UTC, and parse the answers.
  // Oracle: the recorded requests and the returned values.
  // Risk edge: a body field the server does not know (`400`), a naive
  // `expires_at` the server's `DateTime<Utc>` refuses, or a revoke aimed at
  // the wrong path.
  // Layer: integration against the fake LoginFlow.
  // Counterfactual: sending `expires_at` in local time without an offset, or
  // revoking at `/v1/app/members/{id}`, fails the assertions.
  test('invite, grant and revoke speak the members contract', () async {
    final fixture = await signedIn();

    final invited = await fixture.auth.inviteMember(
      organizationId: _clientOrg,
      email: 'new.admin@example.com',
      roleId: 'role-client-admin',
      firstName: 'Luz',
      expiresAt: DateTime.utc(2027, 1, 31, 12),
    );
    final inviteBody =
        jsonDecode(server.membersRequests.last.body) as Map<String, Object?>;
    final granted = await fixture.auth.grantRole(
      organizationId: _clientOrg,
      principalId: 'cu_tomas',
      roleId: 'role-client-admin',
    );
    final grantRequest = server.membersRequests.last;
    final revoked = await fixture.auth.revokeAssignment('as-existing');

    expect(invited.data.invitation, InvitationStatus.sent);
    expect(invited.data.member.email, 'new.admin@example.com');
    expect(invited.data.assignment.role.key, 'client_admin');
    expect(inviteBody, <String, Object?>{
      'organization_id': _clientOrg,
      'email': 'new.admin@example.com',
      'first_name': 'Luz',
      'role_id': 'role-client-admin',
      'expires_at': '2027-01-31T12:00:00.000Z',
    });
    expect(grantRequest.uri.path, '/v1/app/members/cu_tomas/assignments');
    expect(jsonDecode(grantRequest.body), <String, Object?>{
      'organization_id': _clientOrg,
      'role_id': 'role-client-admin',
    });
    expect(granted.data.manageable, isTrue);
    expect(revoked.isOk, isTrue, reason: '$revoked');
    expect(server.membersRequests.last.method, 'DELETE');
    expect(
      server.membersRequests.last.uri.path,
      '/v1/app/members/assignments/as-existing',
    );
  });

  // TEST_CHARTER
  // Requirement: a write past the recent-authentication window is
  // `StepUpRequired` (RFC 9470), ready for `stepUp`.
  // Oracle: the returned error and its `maxAge`.
  // Risk edge: the UI shows a generic failure instead of asking the person
  // to re-authenticate.
  // Layer: integration against the fake LoginFlow.
  // Counterfactual: mapping the `401` without reading `WWW-Authenticate`
  // returns `ServerResponseInvalid`.
  test('a write past the recent sign-in window is StepUpRequired', () async {
    final fixture = await signedIn();
    server.expireRecentAuthentications();

    final invited = await fixture.auth.inviteMember(
      organizationId: _clientOrg,
      email: 'new.admin@example.com',
      roleId: 'role-client-admin',
    );

    expect(
      invited.errorOrNull,
      isA<StepUpRequired>().having(
        (error) => error.requirement.maxAge,
        'maxAge',
        const Duration(seconds: 300),
      ),
    );
  });

  // TEST_CHARTER
  // Requirement: every refusal of the delegation rules is `DelegationDenied`
  // with its code and status, so the UI shows why without parsing text.
  // Oracle: the returned errors.
  // Risk edge: every refusal collapses into one opaque "unexpected server
  // response".
  // Layer: integration against the fake LoginFlow (the API's envelope).
  // Counterfactual: mapping the refusals with the generic account-API error
  // returns `ServerResponseInvalid` and fails every expectation.
  test('refusals are DelegationDenied with the server code', () async {
    final fixture = await signedIn();

    final notGrantable = await fixture.auth.grantRole(
      organizationId: _clientOrg,
      principalId: 'cu_tomas',
      roleId: 'role-owner',
    );
    final self = await fixture.auth.inviteMember(
      organizationId: _clientOrg,
      email: 'ana@example.com',
      roleId: 'role-client-admin',
    );
    final unknownOrganization = await fixture.auth.listGrantableRoles(
      organizationId: 'org-elsewhere',
    );

    expect(
      notGrantable.errorOrNull,
      const DelegationDenied(
        code: DelegationDenialCode.roleNotGrantable,
        statusCode: 403,
      ),
    );
    expect(
      self.errorOrNull,
      const DelegationDenied(
        code: DelegationDenialCode.selfAssignmentForbidden,
        statusCode: 403,
      ),
    );
    expect(
      unknownOrganization.errorOrNull,
      const DelegationDenied(
        code: DelegationDenialCode.organizationNotFound,
        statusCode: 404,
      ),
    );
  });
}
