import 'package:loginflow_auth/src/core/json/json_field_reader.dart';

/// A credential enrolled through the account passkey API (`GET/PATCH/DELETE
/// /v1/user/passkeys[/{id}]`). Never carries the public key or any other
/// credential material — only what the user needs to recognize and manage
/// their own passkeys.
class PasskeyCredential {
  const PasskeyCredential({
    required this.id,
    required this.name,
    required this.createdAt,
    required this.lastUsedAt,
  });

  factory PasskeyCredential.fromJson(Map<String, Object?> json) {
    final lastUsedAt = json.optionalString('last_used_at');
    return PasskeyCredential(
      id: json.requireString('id'),
      name: json.optionalString('name'),
      createdAt: DateTime.parse(json.requireString('created_at')),
      lastUsedAt: lastUsedAt == null ? null : DateTime.parse(lastUsedAt),
    );
  }

  final String id;
  final String? name;
  final DateTime createdAt;
  final DateTime? lastUsedAt;

  PasskeyCredential copyWith({
    String? id,
    String? name,
    DateTime? createdAt,
    DateTime? lastUsedAt,
  }) => PasskeyCredential(
    id: id ?? this.id,
    name: name ?? this.name,
    createdAt: createdAt ?? this.createdAt,
    lastUsedAt: lastUsedAt ?? this.lastUsedAt,
  );

  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'name': ?name,
    'created_at': createdAt.toIso8601String(),
    'last_used_at': ?lastUsedAt?.toIso8601String(),
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PasskeyCredential &&
          id == other.id &&
          name == other.name &&
          createdAt == other.createdAt &&
          lastUsedAt == other.lastUsedAt;

  @override
  int get hashCode => Object.hash(id, name, createdAt, lastUsedAt);
}
