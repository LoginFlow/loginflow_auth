/// Why the external user-agent (system browser) step did not complete.
enum BrowserFailureReason {
  /// The user closed the browser sheet before finishing.
  cancelled,

  /// The platform cannot open an authentication session (no browser, no
  /// presenting window, or no redirect URI configured for this client).
  unavailable,

  /// The platform reported an unexpected failure.
  failed,
}
