/// What signed in with an access code (`subject_kind` claim,
/// `doc/server-contract.md` §16): the tenant backend that issued the code
/// decides it, and it never changes for the subject. Either kind may enroll
/// a passkey after redeeming its code (`LoginFlowAuth.enrollPasskey`).
enum AccessSubjectKind {
  /// A person the tenant backend knows (a driver, a student, a referee).
  person('person'),

  /// A device the tenant backend knows (a kiosk, a recorder).
  device('device');

  const AccessSubjectKind(this.wireName);

  /// The name of this value on the wire.
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
