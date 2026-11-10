/// Why LoginFlow refused to read, approve or deny a sign-in QR
/// (`error.code` of `/v1/user/device-qr/{request_id}/details|approve|deny`,
/// `doc/server-contract.md` §21).
enum SignInQrRefusal {
  /// No QR with this id, or its secret does not match (`404`).
  notFound('device_qr_not_found'),

  /// The QR expired (120 s), was replaced by a newer one on the page, or
  /// was already decided or used (`410`). Ask the page for a new one.
  expired('device_qr_expired'),

  /// The signed-in person may not sign in to the page's client (a
  /// permission the client requires, a deleted profile or membership)
  /// (`403`). Nothing was decided.
  notAllowed('device_qr_not_allowed');

  const SignInQrRefusal(this.wireName);

  /// The name of this value on the wire.
  final String wireName;

  /// The refusal for [value], or `null` for any other `error.code`.
  static SignInQrRefusal? fromWireName(String value) {
    for (final refusal in values) {
      if (refusal.wireName == value) {
        return refusal;
      }
    }
    return null;
  }
}
