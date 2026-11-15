import 'package:loginflow_auth/src/core/json/json_field_reader.dart';
import 'package:loginflow_auth/src/core/json/list_equality.dart';
import 'package:loginflow_auth/src/core/protocol/organizations/organization.dart';
import 'package:loginflow_auth/src/core/protocol/self_selection/self_selectable_role.dart';

/// The roles the signed-in person may take or leave for themself, in the
/// root [organization] of their company and application
/// (`GET /v1/app/self-selectable-roles`, `doc/server-contract.md` §22).
/// Empty [roles]: the application marks none, hide the screen.
class SelfSelectableRoles {
  /// Creates a [SelfSelectableRoles].
  const SelfSelectableRoles({required this.organization, required this.roles});

  /// Reads a [SelfSelectableRoles] from its JSON form ([toJson]).
  factory SelfSelectableRoles.fromJson(Map<String, Object?> json) =>
      SelfSelectableRoles(
        organization: Organization.fromJson(json.requireObject('organization')),
        roles: List<SelfSelectableRole>.unmodifiable(
          json.objectList('roles').map(SelfSelectableRole.fromJson),
        ),
      );

  /// The root organization every role is taken in: its `id` is what
  /// `switchOrganization` takes to use their permissions.
  final Organization organization;

  /// Every self-selectable role of the application, sorted by `key`.
  final List<SelfSelectableRole> roles;

  /// A copy of this [SelfSelectableRoles] with the given fields replaced.
  SelfSelectableRoles copyWith({
    Organization? organization,
    List<SelfSelectableRole>? roles,
  }) => SelfSelectableRoles(
    organization: organization ?? this.organization,
    roles: roles ?? this.roles,
  );

  /// The JSON form of this [SelfSelectableRoles], read back by
  /// [SelfSelectableRoles.fromJson].
  Map<String, Object?> toJson() => <String, Object?>{
    'organization': organization.toJson(),
    'roles': roles.map((role) => role.toJson()).toList(),
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SelfSelectableRoles &&
          organization == other.organization &&
          roles.hasSameValues(other.roles);

  @override
  int get hashCode => Object.hash(organization, roles.valuesHash);
}
