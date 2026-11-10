/// Why LoginFlow refused to approve or deny a sign-in by phone approval
/// (`error.code` of `/v1/user/device-push/{request_id}/approve|deny`,
/// `doc/server-contract.md` §21).
enum PhoneApprovalRefusal {
  /// No such request for the signed-in person (`404`). Someone else's
  /// request answers the same: its existence is never told.
  notFound('device_push_not_found'),

  /// The request expired (120 s), was replaced by a newer one from the
  /// page, or was already decided (`410`). Read the pending list again.
  expired('device_push_expired'),

  /// The signed-in person can no longer sign in to the page's client
  /// directly (a permission the client requires, a deleted profile or
  /// membership) (`403`). Nothing was decided: the request stays pending
  /// until it expires.
  notAllowed('device_push_not_allowed');

  const PhoneApprovalRefusal(this.wireName);

  /// The name of this value on the wire.
  final String wireName;

  /// The refusal for [value], or `null` for any other `error.code`.
  static PhoneApprovalRefusal? fromWireName(String value) {
    for (final refusal in values) {
      if (refusal.wireName == value) {
        return refusal;
      }
    }
    return null;
  }
}
