import 'package:loginflow_auth/src/core/json/json_field_reader.dart';

/// The role of a `MemberAssignment`: never its permissions
/// (`doc/server-contract.md` §18).
class MemberRole {
  const MemberRole({required this.id, required this.key, required this.name});

  factory MemberRole.fromJson(Map<String, Object?> json) => MemberRole(
    id: json.requireString('id'),
    key: json.requireString('key'),
    name: json.requireString('name'),
  );

  final String id;
  final String key;
  final String name;

  MemberRole copyWith({String? id, String? key, String? name}) => MemberRole(
    id: id ?? this.id,
    key: key ?? this.key,
    name: name ?? this.name,
  );

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
