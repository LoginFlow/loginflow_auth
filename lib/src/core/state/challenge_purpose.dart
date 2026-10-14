/// Why a challenge is being asked.
enum ChallengePurpose {
  /// A normal sign-in.
  signIn,

  /// The app asked for stronger authentication (RFC 9470, first-party-apps
  /// §7); the current session stays valid while it runs.
  stepUp,

  /// A refresh was answered with `insufficient_authorization`
  /// (first-party-apps §6.2).
  reauthentication,
}
