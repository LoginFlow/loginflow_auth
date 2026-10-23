import 'package:loginflow_auth/src/core/json/json_field_reader.dart';

/// The role of a `MemberAssignment`: never its permissions
/// (`doc/server-contract.md` §18).
class MemberRole {
  /// Creates a [MemberRole].
  const MemberRole({required this.id, required this.key, required this.name});

  /// Reads a [MemberRole] from its JSON form ([toJson]).
  factory MemberRole.fromJson(Map<String, Object?> json) => MemberRole(
    id: json.requireString('id'),
    key: json.requireString('key'),
    name: json.requireString('name'),
  );

  /// The role's identifier, what `LoginFlowAuth.grantRole` takes.
  final String id;

  /// The application's stable key of the role (e.g. `driver`).
  final String key;

  /// The role's display name.
  final String name;

  /// A copy of this [MemberRole] with the given fields replaced.
  MemberRole copyWith({String? id, String? key, String? name}) => MemberRole(
    id: id ?? this.id,
    key: key ?? this.key,
    name: name ?? this.name,
  );

  /// The JSON form of this [MemberRole], read back by [MemberRole.fromJson].
  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'key': key,
    'name': name,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MemberRole &&
          id == other.id &&
          key == other.key &&
          name == other.name;

  @override
  int get hashCode => Object.hash(id, key, name);
}
