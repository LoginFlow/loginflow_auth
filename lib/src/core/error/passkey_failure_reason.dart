/// Why a passkey (WebAuthn) ceremony could not produce a credential.
enum PasskeyFailureReason {
  /// The app did not configure a [PasskeyAuthenticator] for this platform.
  notConfigured,

  /// The user dismissed the platform's passkey sheet, or the ceremony was
  /// aborted (WebAuthn `NotAllowedError`/`AbortError`).
  userCancelled,

  /// No credential matched the request (targeted `allowCredentials`, or a
  /// discoverable request with no passkey saved for this relying party).
  noCredentialsAvailable,

  /// The device or OS version does not support WebAuthn/passkeys
  /// (WebAuthn `NotSupportedError`).
  notSupported,

  /// The platform refused the relying party for this caller (WebAuthn
  /// `SecurityError`): the RP ID is not valid for the calling origin, or
  /// the domain's association file does not list this app.
  securityError,

  /// The app is not associated with the RP ID's domain: the
  /// `webcredentials:` Associated Domain (iOS/macOS) or the domain's
  /// `assetlinks.json` (Android) is missing or does not list this app.
  domainNotAssociated,

  /// This authenticator already holds a passkey for this account (WebAuthn
  /// `InvalidStateError`, an `excludeCredentials` match). Enrollment only.
  alreadyRegistered,

  /// The ceremony did not finish in time (the platform's own timeout, or
  /// `CorbadoPasskeyAuthenticator.ceremonyTimeout`).
  timeout,

  /// The platform returned something the server-shaped request did not ask
  /// for, or the request/response was not valid JSON of the expected shape.
  invalidResponse,

  /// The platform failed with an error this library does not recognize;
  /// `PasskeyFailed.code`/`description` carry the original for logs.
  unknown,
}
