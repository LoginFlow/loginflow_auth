/// What a pending browser round-trip will complete.
enum PendingPurpose {
  /// A sign-in through the browser.
  signIn('sign_in'),

  /// A step-up of the signed-in user through the browser.
  stepUp('step_up'),

  /// An RP-initiated logout (`SignOutScope.browser`).
  signOut('sign_out');

  const PendingPurpose(this.wireName);

  /// The name of this value on the wire.
  final String wireName;

  /// The value whose [wireName] is the given name, or `null` for an unknown one.
  static PendingPurpose? fromWireName(String value) {
    for (final purpose in values) {
      if (purpose.wireName == value) {
        return purpose;
      }
    }
    return null;
  }
}
