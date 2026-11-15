import 'package:loginflow_auth/src/core/json/json_field_reader.dart';

/// A role the application's owner marked self-selectable, and whether the
/// signed-in person holds it in the root organization right now
/// (`GET /v1/app/self-selectable-roles`, `doc/server-contract.md` §22).
/// Never its permissions.
class SelfSelectableRole {
  /// Creates a [SelfSelectableRole].
  const SelfSelectableRole({
    required this.id,
    required this.key,
    required this.name,
    required this.isHeld,
    this.description,
    this.assignmentId,
  });

  /// Reads a [SelfSelectableRole] from its JSON form ([toJson]).
  factory SelfSelectableRole.fromJson(Map<String, Object?> json) =>
      SelfSelectableRole(
        id: json.requireString('id'),
        key: json.requireString('key'),
        name: json.requireString('name'),
        description: json.optionalString('description'),
        isHeld: json.requireBool('held'),
        assignmentId: json.optionalString('assignment_id'),
      );

  /// What `takeSelfSelectableRole` and `leaveSelfSelectableRole` take.
  final String id;

  /// The role's immutable key (e.g. `seller`).
  final String key;

  /// The role's display name.
  final String name;

  /// What the role is for, when the application described it.
  final String? description;

  /// Whether the person holds it in the root organization (a live
  /// assignment).
  final bool isHeld;

  /// The person's assignment of it, `null` when not [isHeld].
  final String? assignmentId;

  /// A copy of this [SelfSelectableRole] with the given fields replaced.
  SelfSelectableRole copyWith({
    String? id,
    String? key,
    String? name,
    String? description,
    bool? isHeld,
    String? assignmentId,
  }) => SelfSelectableRole(
    id: id ?? this.id,
    key: key ?? this.key,
    name: name ?? this.name,
    description: description ?? this.description,
    isHeld: isHeld ?? this.isHeld,
    assignmentId: assignmentId ?? this.assignmentId,
  );

  /// The JSON form of this [SelfSelectableRole], read back by
  /// [SelfSelectableRole.fromJson].
  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'key': key,
    'name': name,
    'description': description,
    'held': isHeld,
    'assignment_id': assignmentId,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SelfSelectableRole &&
          id == other.id &&
          key == other.key &&
          name == other.name &&
          description == other.description &&
          isHeld == other.isHeld &&
          assignmentId == other.assignmentId;

  @override
  int get hashCode =>
      Object.hash(id, key, name, description, isHeld, assignmentId);
}
