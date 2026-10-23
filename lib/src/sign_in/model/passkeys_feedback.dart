/// The message shown above the passkey manager. Each `PasskeyFailed`
/// reason has its own, so the user reads the real cause of a failed
/// enrollment; a sheet the user dismissed shows nothing.
enum PasskeysFeedback {
  none,
  network,
  sessionEnded,
  rateLimited,
  notFound,
  passkeysUnavailable,
  reauthenticationRequired,
  unexpected,
  passkeyNotConfigured,
  passkeyNotSupported,
  passkeyNoCredentials,
  passkeySecurityError,
  passkeyDomainNotAssociated,
  passkeyAlreadyRegistered,
  passkeyTimeout,
  passkeyInvalidResponse,
  passkeyFailed,
}
