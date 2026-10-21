/// What signed in with an access code (`subject_kind` claim,
/// `doc/server-contract.md` §16): the tenant backend that issued the code
/// decides it, and it never changes for the subject.
enum AccessSubjectKind {
  /// A person the tenant backend knows (a driver, a student, a referee).
  /// May enroll a passkey after redeeming the code.
  person('person'),

  /// A shared device (a kiosk, a recorder). Never enrolls a passkey.
  device('device');

  const AccessSubjectKind(this.wireName);

  final String wireName;

  /// `null` for an absent or unknown value, so a server that adds a kind
  /// does not break older clients.
  static AccessSubjectKind? fromWireName(String? value) {
    for (final kind in values) {
      if (kind.wireName == value) {
        return kind;
      }
    }
    return null;
  }
}
