/// What happened to the invitation email of
/// `LoginFlowAuth.inviteMember` (`doc/server-contract.md` §18). The member
/// and the role stand whatever it is.
enum InvitationStatus {
  /// Handed to the application's email server: the person had no account.
  sent('sent'),

  /// Not sent: the person already had an account in the application.
  notNeeded('not_needed'),

  /// Not sent: too many invitations to this email recently.
  rateLimited('rate_limited'),

  /// Not sent: no email server configured, or the delivery failed.
  failed('failed');

  const InvitationStatus(this.wireName);

  /// The name of this value on the wire.
  final String wireName;

  /// Throws a [FormatException] for any other value.
  static InvitationStatus fromWireName(String value) {
    for (final status in values) {
      if (status.wireName == value) {
        return status;
      }
    }
    throw FormatException('Unknown invitation status "$value".');
  }
}
