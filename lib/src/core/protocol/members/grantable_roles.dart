import 'package:loginflow_auth/src/core/json/json_field_reader.dart';
import 'package:loginflow_auth/src/core/json/list_equality.dart';
import 'package:loginflow_auth/src/core/protocol/members/grantable_role.dart';
import 'package:loginflow_auth/src/core/protocol/organizations/organization.dart';

/// The roles the signed-in user may grant in [organization]
/// (`GET /v1/app/members/grantable-roles`, `doc/server-contract.md` §18).
/// Empty [roles] means no grant power there: hide the "Team" screen.
class GrantableRoles {
  /// Creates a [GrantableRoles].
  const GrantableRoles({required this.organization, required this.roles});

  /// Reads a [GrantableRoles] from its JSON form ([toJson]).
  factory GrantableRoles.fromJson(Map<String, Object?> json) => GrantableRoles(
    organization: Organization.fromJson(json.requireObject('organization')),
    roles: List<GrantableRole>.unmodifiable(
      json.objectList('roles').map(GrantableRole.fromJson),
    ),
  );

  /// The organization the answer is about.
  final Organization organization;

  /// The roles the signed-in user may grant there; empty: none.
  final List<GrantableRole> roles;

  /// Whether the user may grant anything in [organization].
  bool get canGrant => roles.isNotEmpty;

  /// A copy of this [GrantableRoles] with the given fields replaced.
  GrantableRoles copyWith({
    Organization? organization,
    List<GrantableRole>? roles,
  }) => GrantableRoles(
    organization: organization ?? this.organization,
    roles: roles ?? this.roles,
  );

  /// The JSON form of this [GrantableRoles], read back by [GrantableRoles.fromJson].
  Map<String, Object?> toJson() => <String, Object?>{
    'organization': organization.toJson(),
    'roles': roles.map((role) => role.toJson()).toList(),
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GrantableRoles &&
          organization == other.organization &&
          roles.hasSameValues(other.roles);

  @override
  int get hashCode => Object.hash(organization, roles.valuesHash);
}
