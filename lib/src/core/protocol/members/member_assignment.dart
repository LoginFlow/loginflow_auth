import 'package:loginflow_auth/src/core/json/json_field_reader.dart';
import 'package:loginflow_auth/src/core/protocol/members/member_role.dart';

/// A role a member holds in the organization (`doc/server-contract.md`
/// §18).
class MemberAssignment {
  const MemberAssignment({
    required this.id,
    required this.role,
    required this.manageable,
    this.expiresAt,
  });

  factory MemberAssignment.fromJson(Map<String, Object?> json) =>
      MemberAssignment(
        id: json.requireString('id'),
        role: MemberRole.fromJson(json.requireObject('role')),
        manageable: json.requireBool('manageable'),
        expiresAt: json.optionalUtcDateTime('expires_at'),
      );

  /// What `revokeAssignment` takes.
  final String id;
  final MemberRole role;

  /// Whether the signed-in user may revoke it, decided by the server: offer
  /// "revoke" only when `true`.
  final bool manageable;

  /// In UTC; `null` when it never expires.
  final DateTime? expiresAt;

  MemberAssignment copyWith({
    String? id,
    MemberRole? role,
    bool? manageable,
    DateTime? expiresAt,
  }) => MemberAssignment(
    id: id ?? this.id,
    role: role ?? this.role,
    manageable: manageable ?? this.manageable,
    expiresAt: expiresAt ?? this.expiresAt,
  );

  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'role': role.toJson(),
    'expires_at': expiresAt?.toUtc().toIso8601String(),
    'manageable': manageable,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MemberAssignment &&
          id == other.id &&
          role == other.role &&
          manageable == other.manageable &&
          expiresAt == other.expiresAt;

  @override
  int get hashCode => Object.hash(id, role, manageable, expiresAt);
}
