/// Why a federated (upstream) sign-in step could not produce a token.
enum UpstreamFailureReason {
  /// The app did not configure a native token source for this provider.
  notConfigured,

  /// The user dismissed the provider's account picker.
  cancelled,

  /// The device has no account for the provider.
  noCredential,

  /// The provider SDK reported an unexpected failure.
  failed,
}
