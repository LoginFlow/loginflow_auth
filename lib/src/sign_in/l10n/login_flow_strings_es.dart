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
  String get feedbackProviderUnavailable => _l10n.feedbackProviderUnavailable;
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
  @override
  String get useAccessCode => _l10n.useAccessCode;
  @override
  String get accessCodeTitle => _l10n.accessCodeTitle;
  @override
  String get accessCodeInstructions => _l10n.accessCodeInstructions;
  @override
  String get accessCodeHint => _l10n.accessCodeHint;
  @override
  String accessCodeIncomplete(int length) => _l10n.accessCodeIncomplete(length);
  @override
  String get feedbackInvalidAccessCode => _l10n.feedbackInvalidAccessCode;
  @override
  String get feedbackAccessCodesUnavailable =>
      _l10n.feedbackAccessCodesUnavailable;
  @override
  String get feedbackAccessCodeNotConfigured =>
      _l10n.feedbackAccessCodeNotConfigured;
  @override
  String get passkeysTitle => _l10n.passkeysTitle;
  @override
  String get passkeysSubtitle => _l10n.passkeysSubtitle;
  @override
  String get passkeysEmpty => _l10n.passkeysEmpty;
  @override
  String get passkeysLoadFailed => _l10n.passkeysLoadFailed;
  @override
  String get passkeysSignedOut => _l10n.passkeysSignedOut;
  @override
  String get passkeysSharedDevice => _l10n.passkeysSharedDevice;
  @override
  String get addPasskey => _l10n.addPasskey;
  @override
  String get passkeyUnnamed => _l10n.passkeyUnnamed;
  @override
  String passkeyAddedOn(String date) => _l10n.passkeyAddedOn(date);
  @override
  String passkeyLastUsedOn(String date) => _l10n.passkeyLastUsedOn(date);
  @override
  String get renamePasskey => _l10n.renamePasskey;
  @override
  String get deletePasskey => _l10n.deletePasskey;
  @override
  String get passkeyNameLabel => _l10n.passkeyNameLabel;
  @override
  String get passkeyNameRequired => _l10n.passkeyNameRequired;
  @override
  String get saveButton => _l10n.saveButton;
  @override
  String get cancelButton => _l10n.cancelButton;
  @override
  String get deletePasskeyTitle => _l10n.deletePasskeyTitle;
  @override
  String deletePasskeyMessage(String name) => _l10n.deletePasskeyMessage(name);
  @override
  String get reauthenticateTitle => _l10n.reauthenticateTitle;
  @override
  String get reauthenticateMessage => _l10n.reauthenticateMessage;
  @override
  String get feedbackPasskeyNotConfigured => _l10n.feedbackPasskeyNotConfigured;
  @override
  String get feedbackPasskeyNotSupported => _l10n.feedbackPasskeyNotSupported;
  @override
  String get feedbackPasskeyNoCredentials => _l10n.feedbackPasskeyNoCredentials;
  @override
  String get feedbackPasskeySecurityError => _l10n.feedbackPasskeySecurityError;
  @override
  String get feedbackPasskeyDomainNotAssociated =>
      _l10n.feedbackPasskeyDomainNotAssociated;
  @override
  String get feedbackPasskeyAlreadyRegistered =>
      _l10n.feedbackPasskeyAlreadyRegistered;
  @override
  String get feedbackPasskeyTimeout => _l10n.feedbackPasskeyTimeout;
  @override
  String get feedbackPasskeyInvalidResponse =>
      _l10n.feedbackPasskeyInvalidResponse;
  @override
  String get feedbackPasskeyFailed => _l10n.feedbackPasskeyFailed;
  @override
  String get feedbackPasskeyNotFound => _l10n.feedbackPasskeyNotFound;
  @override
  String get feedbackReauthenticationRequired =>
      _l10n.feedbackReauthenticationRequired;
  @override
  String get feedbackRateLimited => _l10n.feedbackRateLimited;
}
