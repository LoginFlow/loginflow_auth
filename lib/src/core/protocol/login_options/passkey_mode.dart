/// How a passkey may be used, for a company whose passkey policy is not
/// `disabled` (`ClientLoginOptions.hasPasskey`, `doc/server-contract.md`
/// §4).
enum PasskeyMode {
  /// A passkey may stand in for the second factor on top of a primary
  /// method; it is never offered as the first-factor button.
  mfaOnly('mfa_only'),

  /// A passkey may also be the first factor on its own.
  passwordless('passwordless');

  const PasskeyMode(this.wireName);

  /// The name of this value on the wire.
  final String wireName;

  /// The value whose [wireName] is the given name, or `null` for an unknown one.
  static PasskeyMode? fromWireName(String value) {
    for (final mode in values) {
      if (mode.wireName == value) {
        return mode;
      }
    }
    return null;
  }
}
