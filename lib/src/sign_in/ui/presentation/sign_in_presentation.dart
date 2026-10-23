import 'package:flutter/material.dart';
import 'package:loginflow_auth/src/core/access_code/access_code_format.dart';
import 'package:loginflow_auth/src/core/sso/sso_candidate.dart';
import 'package:loginflow_auth/src/sign_in/l10n/login_flow_strings.dart';
import 'package:loginflow_auth/src/sign_in/model/auth_method.dart';
import 'package:loginflow_auth/src/sign_in/model/field_error.dart';
import 'package:loginflow_auth/src/sign_in/model/sign_in_copy.dart';
import 'package:loginflow_auth/src/sign_in/model/sign_in_feedback.dart';
import 'package:loginflow_auth/src/sign_in/ui/sign_in_keys.dart';

/// Label and icon of each method's button.
extension AuthMethodPresentation on AuthMethod {
  String toButtonLabel(LoginFlowStrings strings) => switch (this) {
    PasswordMethod() => strings.continueWithPassword,
    EmailOtpMethod() => strings.continueWithEmailCode,
    GoogleMethod() => strings.continueWithGoogle,
    MicrosoftMethod() => strings.continueWithMicrosoft,
    AppleMethod() => strings.continueWithApple,
    FacebookMethod() => strings.continueWithFacebook,
  };

  /// Stable key of the method's button, for tests and integration drivers.
  ValueKey<String> toButtonKey() =>
      ValueKey<String>('${SignInKeys.methodButtonPrefix}.$wireName');

  /// Federated providers carry no icon: their marks are trademarks the app
  /// adds per the providers' branding guidelines (Apple and Facebook render
  /// their own branded button widgets instead of this generic one — see
  /// `MethodPickerStep`).
  IconData? toIcon() => switch (this) {
    PasswordMethod() => Icons.password,
    EmailOtpMethod() => Icons.mail_outline,
    GoogleMethod() ||
    MicrosoftMethod() ||
    AppleMethod() ||
    FacebookMethod() => null,
  };
}

/// Text of the feedback banner; `null` hides it.
extension SignInFeedbackPresentation on SignInFeedback {
  String? toMessage(LoginFlowStrings strings) => switch (this) {
    SignInFeedback.none => null,
    SignInFeedback.invalidCredential => strings.feedbackInvalidCredential,
    SignInFeedback.codeExpired => strings.feedbackCodeExpired,
    SignInFeedback.network => strings.feedbackNetwork,
    SignInFeedback.sessionExpired => strings.feedbackSessionExpired,
    SignInFeedback.sessionRevoked => strings.feedbackSessionRevoked,
    SignInFeedback.ssoUnavailable => strings.feedbackSsoUnavailable,
    SignInFeedback.providerUnavailable => strings.feedbackProviderUnavailable,
    SignInFeedback.unexpected => strings.feedbackUnexpected,
    SignInFeedback.invalidAccessCode => strings.feedbackInvalidAccessCode,
    SignInFeedback.accessCodesUnavailable =>
      strings.feedbackAccessCodesUnavailable,
    SignInFeedback.accessCodeNotConfigured =>
      strings.feedbackAccessCodeNotConfigured,
  };
}

/// Field error texts; `null` means the field is fine.
extension FieldErrorPresentation on FieldError {
  String? toEmailMessage(LoginFlowStrings strings) => switch (this) {
    FieldError.none => null,
    FieldError.required => strings.emailRequired,
    FieldError.invalidEmail ||
    FieldError.incompleteAccessCode => strings.emailInvalid,
  };

  String? toPasswordMessage(LoginFlowStrings strings) => switch (this) {
    FieldError.none => null,
    FieldError.required ||
    FieldError.invalidEmail ||
    FieldError.incompleteAccessCode => strings.passwordRequired,
  };

  String? toCodeMessage(LoginFlowStrings strings) => switch (this) {
    FieldError.none => null,
    FieldError.required || FieldError.invalidEmail => strings.codeRequired,
    FieldError.incompleteAccessCode => strings.accessCodeIncomplete(
      AccessCodeFormat.length,
    ),
  };
}

/// Branded title and subtitle, or the built-in texts.
extension SignInCopyPresentation on SignInCopy {
  String toTitle(LoginFlowStrings strings, String languageCode) =>
      title?.forLanguage(languageCode) ?? strings.signInTitle;

  String toSubtitle(LoginFlowStrings strings, String languageCode) =>
      subtitle?.forLanguage(languageCode) ?? strings.signInSubtitle;
}

/// How the Native SSO account is named in "Continue as …".
extension SsoCandidatePresentation on SsoCandidate {
  String toDisplayName() => name ?? email ?? subject;
}
