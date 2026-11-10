/// Why the previous step input was not accepted (`step_error` member).
///
/// The server sends the same value whether or not the account exists, so the
/// response never reveals account existence (RFC 9700 §4.3 spirit, LoginFlow
/// anti-enumeration rules).
enum StepError {
  /// Wrong password, OTP, TOTP or recovery code.
  invalidCredential('invalid_credential'),

  /// The email OTP expired or was burned after too many attempts.
  codeExpired('code_expired'),

  /// Set by the library, never sent by the server: the phone approval or
  /// the sign-in QR on screen was refused on the phone (or, for a phone
  /// approval, another number was chosen). The poll answered
  /// `access_denied`; ask again to try once more.
  denied('denied'),

  /// Set by the library, never sent by the server: nobody answered the
  /// phone approval or the sign-in QR in time (120 s), or it was replaced.
  /// The poll answered `expired_token`; ask again for a new one.
  expired('expired');

  const StepError(this.wireName);

  /// The name of this value on the wire.
  final String wireName;

  /// The value whose [wireName] is the given name, or `null` for an unknown one.
  static StepError? fromWireName(String? value) {
    for (final error in values) {
      if (error.wireName == value) {
        return error;
      }
    }
    return null;
  }
}
