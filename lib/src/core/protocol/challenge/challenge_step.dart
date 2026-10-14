/// The next step the authorization server asks for, carried in the `next`
/// member of an `insufficient_authorization` response (LoginFlow profile of
/// draft-ietf-oauth-first-party-apps-04 §5.2.2).
enum ChallengeStep {
  password('password'),
  emailOtp('email_otp'),
  totp('totp'),
  recoveryCode('recovery_code'),
  selectMethod('select_method'),
  upstreamToken('upstream_token');

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
