/// Why LoginFlow refused a members call (`error.code`,
/// `doc/server-contract.md` §18): the delegation rules decide every grant
/// and revocation on the server, and this says which one refused.
enum DelegationDenialCode {
  /// The organization is not of the user's company and application.
  organizationNotFound('organization_not_found'),

  /// The role is not of the application.
  roleNotFound('role_not_found'),

  /// The person has no active account in the application.
  memberNotFound('member_not_found'),

  /// The assignment is not of the user's company and application.
  assignmentNotFound('assignment_not_found'),

  /// None of the user's roles reaches the organization.
  organizationOutOfReach('organization_out_of_reach'),

  /// No role of the user lists this role in its "Can grant" list for that
  /// organization.
  roleNotGrantable('role_not_grantable'),

  /// The expiry asked for is later than the user's own assignment there.
  privilegeExceedsGrantor('privilege_exceeds_grantor'),

  /// A person never grants, invites or revokes their own roles.
  selfAssignmentForbidden('self_assignment_forbidden'),

  /// The role cannot be assigned in that kind of organization.
  roleNotAssignableHere('role_not_assignable_here'),

  /// The expiry is not in the future.
  expiresAtInPast('expires_at_in_past'),

  /// The role is managed by LoginFlow itself.
  systemApplication('system_application'),

  /// The application deactivated the person; only its owner reactivates
  /// them.
  memberInactive('member_inactive'),

  /// The token presented is not for LoginFlow (a product API's token).
  wrongAudience('wrong_audience'),

  /// The token is not a person's (an access-code subject's, for example).
  permissionDenied('permission_denied');

  const DelegationDenialCode(this.wireName);

  /// The name of this value on the wire.
  final String wireName;

  /// The code for [value], or `null` for any other `error.code`.
  static DelegationDenialCode? fromWireName(String value) {
    for (final code in values) {
      if (code.wireName == value) {
        return code;
      }
    }
    return null;
  }
}
