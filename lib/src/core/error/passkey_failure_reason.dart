/// Why a passkey (WebAuthn) ceremony could not produce a credential.
enum PasskeyFailureReason {
  /// The app did not configure a [PasskeyAuthenticator] for this platform.
  notConfigured,

  /// The user dismissed the platform's passkey sheet.
  userCancelled,

  /// No credential matched the request (targeted `allowCredentials`, or a
  /// discoverable request with no passkey saved for this relying party).
  noCredentialsAvailable,

  /// The device or OS version does not support WebAuthn/passkeys.
  notSupported,

  /// The platform returned something the server-shaped request did not ask
  /// for, or that was not valid JSON.
  invalidResponse,
}
