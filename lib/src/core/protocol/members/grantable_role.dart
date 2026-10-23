import 'package:loginflow_auth/src/core/json/json_field_reader.dart';

/// A role the signed-in user may grant in one organization
/// (`GET /v1/app/members/grantable-roles`, `doc/server-contract.md` §18):
/// exactly what a grant there would allow.
class GrantableRole {
  /// Creates a [GrantableRole].
  const GrantableRole({
    required this.id,
    required this.key,
    required this.name,
    this.description,
    this.maxExpiresAt,
  });

  /// Reads a [GrantableRole] from its JSON form ([toJson]).
  factory GrantableRole.fromJson(Map<String, Object?> json) => GrantableRole(
    id: json.requireString('id'),
    key: json.requireString('key'),
    name: json.requireString('name'),
    description: json.optionalString('description'),
    maxExpiresAt: json.optionalUtcDateTime('max_expires_at'),
  );

  /// What `inviteMember` and `grantRole` take as `roleId`.
  final String id;

  /// The role's immutable key (e.g. `client_admin`).
  final String key;

  /// The role's display name.
  final String name;

  /// What the role is for, when the application described it.
  final String? description;

  /// The latest expiry the user may give (their own assignment's), in UTC;
  /// `null` when unbounded.
  final DateTime? maxExpiresAt;

  /// A copy of this [GrantableRole] with the given fields replaced.
  GrantableRole copyWith({
    String? id,
    String? key,
    String? name,
    String? description,
    DateTime? maxExpiresAt,
  }) => GrantableRole(
    id: id ?? this.id,
    key: key ?? this.key,
    name: name ?? this.name,
    description: description ?? this.description,
    maxExpiresAt: maxExpiresAt ?? this.maxExpiresAt,
  );

  /// The JSON form of this [GrantableRole], read back by [GrantableRole.fromJson].
  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'key': key,
    'name': name,
    'description': description,
    'max_expires_at': maxExpiresAt?.toUtc().toIso8601String(),
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GrantableRole &&
          id == other.id &&
          key == other.key &&
          name == other.name &&
          description == other.description &&
          maxExpiresAt == other.maxExpiresAt;

  @override
  int get hashCode => Object.hash(id, key, name, description, maxExpiresAt);
}
