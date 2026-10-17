/// The next step the authorization server asks for, carried in the `next`
/// member of an `insufficient_authorization` response (LoginFlow profile of
/// draft-ietf-oauth-first-party-apps-04 §5.2.2).
enum ChallengeStep {
  password('password'),
  emailOtp('email_otp'),
  totp('totp'),
  recoveryCode('recovery_code'),
  selectMethod('select_method'),
  upstreamToken('upstream_token'),

  /// Client-initiated only (`method=webauthn_identify`): never a `next`
  /// value the server sends back (`doc/server-contract.md` passkeys
  /// section). Starts a passkey sign-in, targeted when sent together with
  /// `login_hint` or discoverable/conditional otherwise.
  webauthnIdentify('webauthn_identify'),

  /// Closing leg of a passkey sign-in: answer with the raw
  /// `PublicKeyCredential` JSON from `navigator.credentials.get()`
  /// (`WebauthnAssertionInput`).
  webauthnAssertion('webauthn_assertion'),

  /// Redeems an admin-issued Temporary Access Pass
  /// (`TemporaryAccessPassInput`), identified by the transaction's
  /// `login_hint` like `password`.
  temporaryAccessPass('temporary_access_pass'),

  /// Client-initiated only (`method=magic_link`): sends one email carrying
  /// both a fresh email-OTP code and a magic-link token
  /// (`RequestMagicLinkInput`). The server still answers `next: email_otp`
  /// — never its own `next` value.
  magicLink('magic_link');

  const ChallengeStep(this.wireName);

  final String wireName;

  static ChallengeStep? fromWireName(String value) {
    for (final step in values) {
      if (step.wireName == value) {
        return step;
      }
    }
    return null;
  }
}
