/// How the client will obtain the upstream identity (`upstream_flow`).
enum UpstreamFlow {
  /// The app gets the provider ID token from the platform SDK and posts it
  /// as `upstream_token` (Google via Credential Manager / GIDSignIn).
  native('native'),

  /// The server answers `redirect_to_web` and the provider runs in the
  /// system browser (Microsoft always; Google when no native source exists).
  browser('browser');

  const UpstreamFlow(this.wireName);

  final String wireName;
}
