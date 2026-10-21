// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'login_flow_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class LoginFlowLocalizationsEn extends LoginFlowLocalizations {
  LoginFlowLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get signInTitle => 'Sign in';

  @override
  String get signInSubtitle => 'Choose how you want to continue';

  @override
  String get continueWithPassword => 'Continue with password';

  @override
  String get continueWithEmailCode => 'Email me a code';

  @override
  String get continueWithGoogle => 'Continue with Google';

  @override
  String get continueWithMicrosoft => 'Continue with Microsoft';

  @override
  String get continueWithApple => 'Continue with Apple';

  @override
  String get continueWithFacebook => 'Continue with Facebook';

  @override
  String get continueWithPasskey => 'Continue with a passkey';

  @override
  String get temporaryAccessPassTitle => 'Temporary access pass';

  @override
  String get temporaryAccessPassInstructions =>
      'Enter the temporary access pass your administrator gave you.';

  @override
  String get useTemporaryAccessPass => 'Use a temporary access pass';

  @override
  String get emailLabel => 'Email';

  @override
  String get passwordLabel => 'Password';

  @override
  String get showPassword => 'Show password';

  @override
  String get hidePassword => 'Hide password';

  @override
  String get signInButton => 'Sign in';

  @override
  String get forgotPassword => 'Forgot your password?';

  @override
  String get sendCodeButton => 'Send code';

  @override
  String get codeLabel => 'Code';

  @override
  String codeSentTo(String email) {
    return 'We sent a code to $email';
  }

  @override
  String get verifyButton => 'Verify';

  @override
  String get resendCode => 'Resend code';

  @override
  String resendIn(int seconds) {
    return 'Resend code in ${seconds}s';
  }

  @override
  String get sendMagicLink => 'Email me a sign-in link instead';

  @override
  String get twoStepTitle => 'Two-step verification';

  @override
  String get authenticatorInstructions =>
      'Enter the 6-digit code from your authenticator app.';

  @override
  String get recoveryInstructions => 'Enter one of your recovery codes.';

  @override
  String get useRecoveryCode => 'Use a recovery code';

  @override
  String get useAuthenticatorCode => 'Use your authenticator app';

  @override
  String get back => 'Back';

  @override
  String get createAccount => 'Create an account';

  @override
  String get continueInBrowser => 'Continue in your browser…';

  @override
  String continueAs(String name) {
    return 'Continue as $name';
  }

  @override
  String get ssoSubtitle =>
      'You are already signed in to another app on this device.';

  @override
  String get useAnotherAccount => 'Use another account';

  @override
  String get lockedOutTitle => 'Too many attempts';

  @override
  String lockedOutMessage(int seconds) {
    return 'Try again in $seconds seconds.';
  }

  @override
  String get tryAgain => 'Try again';

  @override
  String get optionsUnavailable => 'Sign-in options could not be loaded.';

  @override
  String get noMethods => 'No sign-in method is available for this app.';

  @override
  String get notConfigured => 'Sign-in is not configured.';

  @override
  String get feedbackInvalidCredential =>
      'The details you entered are not correct.';

  @override
  String get feedbackCodeExpired => 'That code expired. Request a new one.';

  @override
  String get feedbackNetwork => 'Check your connection and try again.';

  @override
  String get feedbackSessionExpired => 'Signing in took too long. Start again.';

  @override
  String get feedbackSessionRevoked => 'Your session ended. Sign in again.';

  @override
  String get feedbackSsoUnavailable =>
      'That session is no longer available. Sign in to continue.';

  @override
  String get feedbackProviderUnavailable =>
      'That sign-in option is not available on this device.';

  @override
  String get feedbackUnexpected => 'Something went wrong. Try again.';

  @override
  String get emailRequired => 'Enter your email';

  @override
  String get emailInvalid => 'Enter a valid email';

  @override
  String get passwordRequired => 'Enter your password';

  @override
  String get codeRequired => 'Enter the code';

  @override
  String get legalTermsLabel => 'Terms';

  @override
  String get legalPrivacyLabel => 'Privacy Policy';

  @override
  String legalFooterBoth(String terms, String policy) {
    return 'By continuing, you accept the $terms and the $policy.';
  }

  @override
  String legalFooterTermsOnly(String terms) {
    return 'By continuing, you accept the $terms.';
  }

  @override
  String legalFooterPolicyOnly(String policy) {
    return 'By continuing, you accept the $policy.';
  }

  @override
  String get useAccessCode => 'I have an access code';

  @override
  String get accessCodeTitle => 'Access code';

  @override
  String get accessCodeInstructions => 'Enter the access code you were given.';

  @override
  String get accessCodeHint => 'XXXX-XXXX';

  @override
  String accessCodeIncomplete(int length) {
    return 'Enter the $length characters of the code';
  }

  @override
  String get feedbackInvalidAccessCode =>
      'That access code is not valid: it may be mistyped, expired or already used. Check it or ask for a new one.';

  @override
  String get feedbackAccessCodesUnavailable =>
      'Access codes are not available for this app.';

  @override
  String get feedbackAccessCodeNotConfigured =>
      'This app is not set up to sign in with access codes.';

  @override
  String get passkeysTitle => 'Passkeys';

  @override
  String get passkeysSubtitle =>
      'Sign in without a password using your device\'s screen lock.';

  @override
  String get passkeysEmpty => 'You have no passkeys yet.';

  @override
  String get passkeysLoadFailed => 'Your passkeys could not be loaded.';

  @override
  String get passkeysSignedOut => 'Sign in to manage your passkeys.';

  @override
  String get passkeysSharedDevice =>
      'This account belongs to a shared device, so it cannot have passkeys.';

  @override
  String get addPasskey => 'Add a passkey';

  @override
  String get passkeyUnnamed => 'Passkey';

  @override
  String passkeyAddedOn(String date) {
    return 'Added $date';
  }

  @override
  String passkeyLastUsedOn(String date) {
    return 'Last used $date';
  }

  @override
  String get renamePasskey => 'Rename';

  @override
  String get deletePasskey => 'Delete';

  @override
  String get passkeyNameLabel => 'Name';

  @override
  String get passkeyNameRequired => 'Enter a name';

  @override
  String get saveButton => 'Save';

  @override
  String get cancelButton => 'Cancel';

  @override
  String get deletePasskeyTitle => 'Delete this passkey?';

  @override
  String deletePasskeyMessage(String name) {
    return 'You will no longer be able to sign in with “$name”.';
  }

  @override
  String get reauthenticateTitle => 'Confirm it\'s you';

  @override
  String get reauthenticateMessage => 'To add a passkey, sign in again.';

  @override
  String get feedbackPasskeyNotConfigured =>
      'Passkeys are not set up in this app.';

  @override
  String get feedbackPasskeyNotSupported => 'This device cannot use passkeys.';

  @override
  String get feedbackPasskeyNoCredentials =>
      'No passkey is available on this device.';

  @override
  String get feedbackPasskeySecurityError =>
      'This app is not allowed to use passkeys for this account.';

  @override
  String get feedbackPasskeyDomainNotAssociated =>
      'This app is not linked to the passkey domain yet.';

  @override
  String get feedbackPasskeyAlreadyRegistered =>
      'This device already has a passkey for your account.';

  @override
  String get feedbackPasskeyTimeout =>
      'The passkey took too long to respond. Try again.';

  @override
  String get feedbackPasskeyInvalidResponse =>
      'The device returned an invalid response. Try again.';

  @override
  String get feedbackPasskeyFailed => 'The passkey could not be created.';

  @override
  String get feedbackPasskeyNotFound => 'That passkey no longer exists.';

  @override
  String get feedbackReauthenticationRequired =>
      'Sign in again to add a passkey.';

  @override
  String get feedbackRateLimited =>
      'Too many attempts. Wait a moment and try again.';
}
