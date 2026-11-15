import 'package:flutter_test/flutter_test.dart';
import 'package:loginflow_auth/loginflow_auth_core.dart';

/// The members models (`doc/server-contract.md` §18) read the JSON
/// `loginflow_api` sends, round-trip through `toJson`, and compare by value.
void main() {
  const role = <String, Object?>{
    'id': 'role-1',
    'key': 'client_admin',
    'name': 'Admin de cliente',
  };
  const assignment = <String, Object?>{
    'id': 'as-1',
    'role': role,
    'expires_at': '2026-12-31T23:59:59',
    'manageable': true,
  };
  const member = <String, Object?>{
    'principal_id': 'cu_ana',
    'email': 'ana@example.com',
    'name': 'Ana Ruiz',
    'assignments': <Object?>[assignment],
  };

  /// [fromJson] reads [wire]; its `toJson` reads back to an equal value with
  /// the same hash; `copyWith()` keeps every field.
  void roundTrips<T extends Object>(
    Map<String, Object?> wire,
    T Function(Map<String, Object?> json) fromJson,
    Map<String, Object?> Function(T value) toJson,
    T Function(T value) copy,
  ) {
    final value = fromJson(wire);
    final again = fromJson(toJson(value));
    expect(again, value);
    expect(again.hashCode, value.hashCode);
    expect(copy(value), value);
  }

  // TEST_CHARTER
  // Requirement: an instant the API sends without an offset (its
  // `NaiveDateTime`, always UTC) is read as that UTC instant, never as the
  // device's local time; one with an offset keeps its instant.
  // Oracle: the parsed `DateTime` equals the UTC instant (value and isUtc).
  // Risk edge: an expiry shown hours off on a device outside UTC.
  // Layer: the model's JSON contract.
  // Counterfactual: parsing with `DateTime.parse` alone yields a local
  // `DateTime` (isUtc false), which is not equal to the UTC instant.
  test('an instant without an offset is read as UTC', () {
    final naive = MemberAssignment.fromJson(assignment);
    final withOffset = MemberAssignment.fromJson(<String, Object?>{
      ...assignment,
      'expires_at': '2027-01-01T01:59:59+02:00',
    });

    expect(naive.expiresAt, DateTime.utc(2026, 12, 31, 23, 59, 59));
    expect(withOffset.expiresAt, DateTime.utc(2026, 12, 31, 23, 59, 59));
  });

  test('every members model round-trips and compares by value', () {
    roundTrips(
      role,
      MemberRole.fromJson,
      (value) => value.toJson(),
      (value) => value.copyWith(),
    );
    roundTrips(
      assignment,
      MemberAssignment.fromJson,
      (value) => value.toJson(),
      (value) => value.copyWith(),
    );
    roundTrips(
      member,
      OrganizationMember.fromJson,
      (value) => value.toJson(),
      (value) => value.copyWith(),
    );
    roundTrips(
      const <String, Object?>{
        'principal_id': 'cu_ana',
        'email': 'ana@example.com',
        'name': null,
      },
      MemberIdentity.fromJson,
      (value) => value.toJson(),
      (value) => value.copyWith(),
    );
    roundTrips(
      const <String, Object?>{
        'items': <Object?>[member],
        'total': 1,
      },
      MembersPage.fromJson,
      (value) => value.toJson(),
      (value) => value.copyWith(),
    );
    roundTrips(
      const <String, Object?>{
        'id': 'role-1',
        'key': 'client_admin',
        'name': 'Admin de cliente',
        'description': null,
        'max_expires_at': '2027-06-30T00:00:00',
      },
      GrantableRole.fromJson,
      (value) => value.toJson(),
      (value) => value.copyWith(),
    );
    roundTrips(
      const <String, Object?>{
        'organization': <String, Object?>{
          'id': 'org-1',
          'name': 'Transportes Norte',
          'kind': 'regular',
        },
        'roles': <Object?>[],
      },
      GrantableRoles.fromJson,
      (value) => value.toJson(),
      (value) => value.copyWith(),
    );
    roundTrips(
      const <String, Object?>{
        'member': <String, Object?>{
          'principal_id': 'cu_luz',
          'email': 'luz@example.com',
          'name': 'Luz',
        },
        'assignment': assignment,
        'invitation': 'not_needed',
      },
      MemberInvitation.fromJson,
      (value) => value.toJson(),
      (value) => value.copyWith(),
    );
  });

  test('every self-selectable roles model round-trips and compares by '
      'value', () {
    const held = <String, Object?>{
      'id': 'role-seller',
      'key': 'seller',
      'name': 'Seller',
      'description': null,
      'held': true,
      'assignment_id': 'as-1',
    };
    roundTrips(
      held,
      SelfSelectableRole.fromJson,
      (value) => value.toJson(),
      (value) => value.copyWith(),
    );
    roundTrips(
      const <String, Object?>{
        'organization': <String, Object?>{
          'id': 'org-root',
          'name': 'TurnosQR',
          'kind': 'root',
        },
        'roles': <Object?>[held],
      },
      SelfSelectableRoles.fromJson,
      (value) => value.toJson(),
      (value) => value.copyWith(),
    );
    roundTrips(
      const <String, Object?>{
        'assignment_id': 'as-1',
        'organization_id': 'org-root',
        'role': role,
        'created': true,
      },
      SelfSelectedRole.fromJson,
      (value) => value.toJson(),
      (value) => value.copyWith(),
    );
  });

  // Requirement: a passkey-only account (API 0.26.0, no email) is listed by
  // `GET /v1/app/members` with `email: null`; the page still loads.
  // Oracle: the parsed member carries no email and round-trips.
  test('a member without an email is read and round-trips', () {
    final emailLess = <String, Object?>{
      ...member,
      'principal_id': 'cu_passkey_1',
      'email': null,
      'name': null,
    };

    final read = OrganizationMember.fromJson(emailLess);

    expect(read.identity.principalId, 'cu_passkey_1');
    expect(read.identity.email, isNull);
    expect(read.identity.name, isNull);
    roundTrips(
      emailLess,
      OrganizationMember.fromJson,
      (value) => value.toJson(),
      (value) => value.copyWith(),
    );
  });

  test('values differ when a field differs', () {
    final first = MemberAssignment.fromJson(assignment);

    expect(first.copyWith(manageable: false), isNot(first));
    expect(
      first.copyWith(role: first.role.copyWith(key: 'driver')),
      isNot(first),
    );
  });

  test('an empty grantable list means no grant power', () {
    final none = GrantableRoles.fromJson(const <String, Object?>{
      'organization': <String, Object?>{
        'id': 'org-1',
        'name': 'Raíz',
        'kind': 'root',
      },
      'roles': <Object?>[],
    });

    expect(none.canGrant, isFalse);
    expect(none.organization.kind, OrganizationKind.root);
  });

  test('every invitation status reads its wire name; any other is refused', () {
    for (final status in InvitationStatus.values) {
      expect(InvitationStatus.fromWireName(status.wireName), status);
    }
    expect(InvitationStatus.notNeeded.wireName, 'not_needed');
    expect(
      () => InvitationStatus.fromWireName('queued'),
      throwsFormatException,
    );
  });
}
