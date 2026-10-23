/// The next step the authorization server asks for, carried in the `next`
/// member of an `insufficient_authorization` response (LoginFlow profile of
/// draft-ietf-oauth-first-party-apps-04 §5.2.2).
enum ChallengeStep {
  /// The account password.
  password('password'),

  /// A one-time code emailed to the user.
  emailOtp('email_otp'),

  /// A 6-digit code of the user's authenticator app (second factor).
  totp('totp'),

  /// A single-use TOTP recovery code, instead of the authenticator app.
  recoveryCode('recovery_code'),

  /// Choose a primary method among `ChallengeStepRequired.methods`.
  selectMethod('select_method'),

  /// A Google, Apple or Facebook token obtained natively (answered by the
  /// library itself through the configured source).
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
  magicLink('magic_link'),

  /// Client-initiated only (`method=access_code`): redeems a single-use
  /// code a tenant backend issued for one of its own subjects
  /// (`AccessCodeInput`, `doc/server-contract.md` §16). One leg: the server
  /// answers with an authorization code or an error, never a `next` value.
  accessCode('access_code');

  const ChallengeStep(this.wireName);

  /// The name of this value on the wire.
  final String wireName;

  /// The value whose [wireName] is the given name, or `null` for an unknown one.
  static ChallengeStep? fromWireName(String value) {
    for (final step in values) {
      if (step.wireName == value) {
        return step;
      }
    }
    return null;
  }
}
