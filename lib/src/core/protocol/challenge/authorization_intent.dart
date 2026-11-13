/// `intent` values of an opening challenge request
/// (draft-ietf-oauth-first-party-apps-04 Appendix A.2,
/// `doc/server-contract.md` §5.4).
enum AuthorizationIntent {
  /// The in-app password reset, sent together with `method=email_otp`: the
  /// server keeps it in the app and never creates nor activates an account
  /// for it.
  passwordReset('password_reset');

  const AuthorizationIntent(this.wireName);

  /// The name of this value on the wire.
  final String wireName;
}
