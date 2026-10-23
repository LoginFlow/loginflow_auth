import 'package:loginflow_auth/src/core/json/json_field_reader.dart';

/// A credential enrolled through the account passkey API (`GET/PATCH/DELETE
/// /v1/user/passkeys[/{id}]`). Never carries the public key or any other
/// credential material — only what the user needs to recognize and manage
/// their own passkeys.
class PasskeyCredential {
  /// Creates a [PasskeyCredential].
  const PasskeyCredential({
    required this.id,
    required this.name,
    required this.createdAt,
    required this.lastUsedAt,
  });

  /// Reads a [PasskeyCredential] from its JSON form ([toJson]).
  factory PasskeyCredential.fromJson(Map<String, Object?> json) {
    final lastUsedAt = json.optionalString('last_used_at');
    return PasskeyCredential(
      id: json.requireString('id'),
      name: json.optionalString('name'),
      createdAt: DateTime.parse(json.requireString('created_at')),
      lastUsedAt: lastUsedAt == null ? null : DateTime.parse(lastUsedAt),
    );
  }

  /// The credential's identifier, for [LoginFlowAuth.renamePasskey] and
  /// [LoginFlowAuth.deletePasskey].
  final String id;

  /// The name the user gave it, when any.
  final String? name;

  /// When it was enrolled.
  final DateTime createdAt;

  /// When it last signed in, when ever.
  final DateTime? lastUsedAt;

  /// A copy of this [PasskeyCredential] with the given fields replaced.
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

  /// The JSON form of this [PasskeyCredential], read back by [PasskeyCredential.fromJson].
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
