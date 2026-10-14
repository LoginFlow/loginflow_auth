/// What a pending browser round-trip will complete.
enum PendingPurpose {
  signIn('sign_in'),
  stepUp('step_up'),
  signOut('sign_out');

  const PendingPurpose(this.wireName);

  final String wireName;

  static PendingPurpose? fromWireName(String value) {
    for (final purpose in values) {
      if (purpose.wireName == value) {
        return purpose;
      }
    }
    return null;
  }
}
