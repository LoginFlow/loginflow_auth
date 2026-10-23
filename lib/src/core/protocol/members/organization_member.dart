import 'package:loginflow_auth/src/core/json/json_field_reader.dart';
import 'package:loginflow_auth/src/core/json/list_equality.dart';
import 'package:loginflow_auth/src/core/protocol/members/member_assignment.dart';
import 'package:loginflow_auth/src/core/protocol/members/member_identity.dart';

/// A person holding at least one role in the organization, with those roles
/// (`GET /v1/app/members`, `doc/server-contract.md` §18).
class OrganizationMember {
  /// Creates an [OrganizationMember].
  const OrganizationMember({required this.identity, required this.assignments});

  /// Reads an [OrganizationMember] from its JSON form ([toJson]).
  factory OrganizationMember.fromJson(Map<String, Object?> json) =>
      OrganizationMember(
        identity: MemberIdentity.fromJson(json),
        assignments: List<MemberAssignment>.unmodifiable(
          json.objectList('assignments').map(MemberAssignment.fromJson),
        ),
      );

  /// Who the member is.
  final MemberIdentity identity;

  /// The member's roles in the organization.
  final List<MemberAssignment> assignments;

  /// A copy of this [OrganizationMember] with the given fields replaced.
  OrganizationMember copyWith({
    MemberIdentity? identity,
    List<MemberAssignment>? assignments,
  }) => OrganizationMember(
    identity: identity ?? this.identity,
    assignments: assignments ?? this.assignments,
  );

  /// The wire shape: the identity's fields and `assignments`, flat.
  Map<String, Object?> toJson() => <String, Object?>{
    ...identity.toJson(),
    'assignments': assignments
        .map((assignment) => assignment.toJson())
        .toList(),
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is OrganizationMember &&
          identity == other.identity &&
          assignments.hasSameValues(other.assignments);

  @override
  int get hashCode => Object.hash(identity, assignments.valuesHash);
}
