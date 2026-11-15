import 'package:loginflow_auth/src/core/json/json_field_reader.dart';
import 'package:loginflow_auth/src/core/protocol/members/member_role.dart';

/// The answer of `LoginFlowAuth.takeSelfSelectableRole`
/// (`PUT /v1/app/self-selectable-roles/{role_id}`,
/// `doc/server-contract.md` §22): the person's assignment of the role in
/// the root organization, and whether the take created it.
class SelfSelectedRole {
  /// Creates a [SelfSelectedRole].
  const SelfSelectedRole({
    required this.assignmentId,
    required this.organizationId,
    required this.role,
    required this.isNew,
  });

  /// Reads a [SelfSelectedRole] from its JSON form ([toJson]): the take's
  /// body plus `created`, which the body does not carry — the status says
  /// it (`201` new, `200` already held).
  factory SelfSelectedRole.fromJson(Map<String, Object?> json) =>
      SelfSelectedRole(
        assignmentId: json.requireString('assignment_id'),
        organizationId: json.requireString('organization_id'),
        role: MemberRole.fromJson(json.requireObject('role')),
        isNew: json.requireBool('created'),
      );

  /// The person's assignment of [role].
  final String assignmentId;

  /// The root organization the role is held in.
  final String organizationId;

  /// The role taken: never its permissions.
  final MemberRole role;

  /// `true` when the take assigned it (`201`), `false` when the person
  /// already held it (`200`: nothing written, nothing counted).
  final bool isNew;

  /// A copy of this [SelfSelectedRole] with the given fields replaced.
  SelfSelectedRole copyWith({
    String? assignmentId,
    String? organizationId,
    MemberRole? role,
    bool? isNew,
  }) => SelfSelectedRole(
    assignmentId: assignmentId ?? this.assignmentId,
    organizationId: organizationId ?? this.organizationId,
    role: role ?? this.role,
    isNew: isNew ?? this.isNew,
  );

  /// The JSON form of this [SelfSelectedRole], read back by
  /// [SelfSelectedRole.fromJson].
  Map<String, Object?> toJson() => <String, Object?>{
    'assignment_id': assignmentId,
    'organization_id': organizationId,
    'role': role.toJson(),
    'created': isNew,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SelfSelectedRole &&
          assignmentId == other.assignmentId &&
          organizationId == other.organizationId &&
          role == other.role &&
          isNew == other.isNew;

  @override
  int get hashCode => Object.hash(assignmentId, organizationId, role, isNew);
}
