import 'package:loginflow_auth/src/core/json/json_field_reader.dart';
import 'package:loginflow_auth/src/core/protocol/members/invitation_status.dart';
import 'package:loginflow_auth/src/core/protocol/members/member_assignment.dart';
import 'package:loginflow_auth/src/core/protocol/members/member_identity.dart';

/// The answer of `LoginFlowAuth.inviteMember`
/// (`POST /v1/app/members/invitations`, `doc/server-contract.md` §18): the
/// member (found or created), the role granted, and the invitation email's
/// outcome.
class MemberInvitation {
  /// Creates a [MemberInvitation].
  const MemberInvitation({
    required this.member,
    required this.assignment,
    required this.invitation,
  });

  /// Reads a [MemberInvitation] from its JSON form ([toJson]).
  factory MemberInvitation.fromJson(Map<String, Object?> json) =>
      MemberInvitation(
        member: MemberIdentity.fromJson(json.requireObject('member')),
        assignment: MemberAssignment.fromJson(json.requireObject('assignment')),
        invitation: InvitationStatus.fromWireName(
          json.requireString('invitation'),
        ),
      );

  /// The person, found or created.
  final MemberIdentity member;

  /// The role they now hold in the organization.
  final MemberAssignment assignment;

  /// Whether the invitation email went out.
  final InvitationStatus invitation;

  /// A copy of this [MemberInvitation] with the given fields replaced.
  MemberInvitation copyWith({
    MemberIdentity? member,
    MemberAssignment? assignment,
    InvitationStatus? invitation,
  }) => MemberInvitation(
    member: member ?? this.member,
    assignment: assignment ?? this.assignment,
    invitation: invitation ?? this.invitation,
  );

  /// The JSON form of this [MemberInvitation], read back by [MemberInvitation.fromJson].
  Map<String, Object?> toJson() => <String, Object?>{
    'member': member.toJson(),
    'assignment': assignment.toJson(),
    'invitation': invitation.wireName,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MemberInvitation &&
          member == other.member &&
          assignment == other.assignment &&
          invitation == other.invitation;

  @override
  int get hashCode => Object.hash(member, assignment, invitation);
}
