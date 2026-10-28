/// The message shown above the current step.
enum SignInFeedback {
  none,
  invalidCredential,
  codeExpired,
  network,
  sessionExpired,
  sessionRevoked,
  ssoUnavailable,
  providerUnavailable,
  unexpected,

  /// The server refused the access code: unknown, expired, already used or
  /// revoked — it never tells them apart (`doc/server-contract.md` §16).
  invalidAccessCode,

  /// Access codes are disabled for the application, or the server has no
  /// way to redeem them.
  accessCodesUnavailable,

  /// The app cannot redeem access codes: no DPoP key store
  /// (`LoginFlowConfig.enableDpop`).
  accessCodeNotConfigured,

  /// The new password of a reset was refused: too weak, found in a data
  /// breach, or the current one (`PasswordRejected`).
  passwordRejected,
}
