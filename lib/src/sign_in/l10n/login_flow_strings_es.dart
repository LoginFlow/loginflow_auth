import 'package:loginflow_auth/src/sign_in/l10n/generated/login_flow_localizations_es.dart';
import 'package:loginflow_auth/src/sign_in/l10n/login_flow_strings.dart';

/// Spanish texts, sourced from the ARB-generated
/// [LoginFlowLocalizationsEs]. Hand-written only to satisfy
/// [LoginFlowStrings]; every value lives in
/// `lib/src/sign_in/l10n/arb/login_flow_es.arb` (the library's base
/// locale).
final class LoginFlowStringsEs implements LoginFlowStrings {
  const LoginFlowStringsEs();

  static final LoginFlowLocalizationsEs _l10n = LoginFlowLocalizationsEs();

  @override
  String get signInTitle => _l10n.signInTitle;
  @override
  String get signInSubtitle => _l10n.signInSubtitle;
  @override
  String get continueWithPassword => _l10n.continueWithPassword;
  @override
  String get continueWithEmailCode => _l10n.continueWithEmailCode;
  @override
  String get continueWithGoogle => _l10n.continueWithGoogle;
  @override
  String get continueWithMicrosoft => _l10n.continueWithMicrosoft;
  @override
  String get continueWithApple => _l10n.continueWithApple;
  @override
  String get continueWithFacebook => _l10n.continueWithFacebook;
  @override
  String get continueWithPasskey => _l10n.continueWithPasskey;
  @override
  String get temporaryAccessPassTitle => _l10n.temporaryAccessPassTitle;
  @override
  String get temporaryAccessPassInstructions =>
      _l10n.temporaryAccessPassInstructions;
  @override
  String get useTemporaryAccessPass => _l10n.useTemporaryAccessPass;
  @override
  String get emailLabel => _l10n.emailLabel;
  @override
  String get passwordLabel => _l10n.passwordLabel;
  @override
  String get showPassword => _l10n.showPassword;
  @override
  String get hidePassword => _l10n.hidePassword;
  @override
  String get signInButton => _l10n.signInButton;
  @override
  String get forgotPassword => _l10n.forgotPassword;
  @override
  String get sendCodeButton => _l10n.sendCodeButton;
  @override
  String get codeLabel => _l10n.codeLabel;
  @override
  String codeSentTo(String email) => _l10n.codeSentTo(email);
  @override
  String get verifyButton => _l10n.verifyButton;
  @override
  String get resendCode => _l10n.resendCode;
  @override
  String resendIn(int seconds) => _l10n.resendIn(seconds);
  @override
  String get sendMagicLink => _l10n.sendMagicLink;
  @override
  String get twoStepTitle => _l10n.twoStepTitle;
  @override
  String get authenticatorInstructions => _l10n.authenticatorInstructions;
  @override
  String get recoveryInstructions => _l10n.recoveryInstructions;
  @override
  String get useRecoveryCode => _l10n.useRecoveryCode;
  @override
  String get useAuthenticatorCode => _l10n.useAuthenticatorCode;
  @override
  String get back => _l10n.back;
  @override
  String get createAccount => _l10n.createAccount;
  @override
  String get continueInBrowser => _l10n.continueInBrowser;
  @override
  String continueAs(String name) => _l10n.continueAs(name);
  @override
  String get ssoSubtitle => _l10n.ssoSubtitle;
  @override
  String get useAnotherAccount => _l10n.useAnotherAccount;
  @override
  String get lockedOutTitle => _l10n.lockedOutTitle;
  @override
  String lockedOutMessage(int seconds) => _l10n.lockedOutMessage(seconds);
  @override
  String get tryAgain => _l10n.tryAgain;
  @override
  String get optionsUnavailable => _l10n.optionsUnavailable;
  @override
  String get noMethods => _l10n.noMethods;
  @override
  String get notConfigured => _l10n.notConfigured;
  @override
  String get feedbackInvalidCredential => _l10n.feedbackInvalidCredential;
  @override
  String get feedbackCodeExpired => _l10n.feedbackCodeExpired;
  @override
  String get feedbackNetwork => _l10n.feedbackNetwork;
  @override
  String get feedbackSessionExpired => _l10n.feedbackSessionExpired;
  @override
  String get feedbackSessionRevoked => _l10n.feedbackSessionRevoked;
  @override
  String get feedbackSsoUnavailable => _l10n.feedbackSsoUnavailable;
  @override
  String get feedbackProviderUnavailable =>
      _l10n.feedbackProviderUnavailable;
  @override
  String get feedbackUnexpected => _l10n.feedbackUnexpected;
  @override
  String get emailRequired => _l10n.emailRequired;
  @override
  String get emailInvalid => _l10n.emailInvalid;
  @override
  String get passwordRequired => _l10n.passwordRequired;
  @override
  String get codeRequired => _l10n.codeRequired;
  @override
  String get legalTermsLabel => _l10n.legalTermsLabel;
  @override
  String get legalPrivacyLabel => _l10n.legalPrivacyLabel;
  @override
  String legalFooterBoth(String terms, String policy) =>
      _l10n.legalFooterBoth(terms, policy);
  @override
  String legalFooterTermsOnly(String terms) =>
      _l10n.legalFooterTermsOnly(terms);
  @override
  String legalFooterPolicyOnly(String policy) =>
      _l10n.legalFooterPolicyOnly(policy);
}
