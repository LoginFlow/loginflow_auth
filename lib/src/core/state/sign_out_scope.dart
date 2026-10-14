/// How far a sign-out reaches (`doc/decisions.md` D14).
enum SignOutScope {
  /// Revoke this app's refresh token and clear its local state; sibling apps
  /// stay signed in through the shared device session.
  app,

  /// End the device session (`sid`) on the server and delete the shared SSO
  /// entry: every app of the publisher on this device is signed out at its
  /// next refresh.
  device,

  /// [app] plus RP-initiated logout of the authorization server browser
  /// session (`end_session_endpoint`).
  browser,

  /// End every session of the user in the company, on every device.
  everywhere,
}
