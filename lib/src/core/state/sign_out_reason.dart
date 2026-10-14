/// Why the state is `SignedOut`.
enum SignOutReason {
  /// Nobody signed in yet, or the user chose another account.
  none,

  /// The user signed out.
  userRequested,

  /// The refresh token was rejected (expired, revoked or reused, RFC 9700
  /// §4.14.2); local state was cleared.
  sessionRevoked,

  /// Another app ended the device session (the shared SSO entry is gone).
  deviceSessionEnded,

  /// The sign-in `auth_session` expired (`invalid_session`).
  challengeExpired,

  /// A silent browser sign-in (`prompt=none`) found no session.
  loginRequired,

  /// The shared Native SSO session could not be used.
  ssoUnavailable,
}
