import 'package:loginflow_auth/src/sign_in/l10n/login_flow_strings.dart';

/// English texts.
final class LoginFlowStringsEn implements LoginFlowStrings {
  const LoginFlowStringsEn();

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
  String codeSentTo(String email) => 'We sent a code to $email';
  @override
  String get verifyButton => 'Verify';
  @override
  String get resendCode => 'Resend code';
  @override
  String resendIn(int seconds) => 'Resend code in ${seconds}s';
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
  String continueAs(String name) => 'Continue as $name';
  @override
  String get ssoSubtitle =>
      'You are already signed in to another app on this device.';
  @override
  String get useAnotherAccount => 'Use another account';
  @override
  String get lockedOutTitle => 'Too many attempts';
  @override
  String lockedOutMessage(int seconds) => 'Try again in $seconds seconds.';
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
}
