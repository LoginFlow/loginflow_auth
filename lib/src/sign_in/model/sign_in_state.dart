import 'package:loginflow_auth/src/sign_in/model/field_error.dart';
import 'package:loginflow_auth/src/sign_in/model/sign_in_copy.dart';
import 'package:loginflow_auth/src/sign_in/model/sign_in_feedback.dart';
import 'package:loginflow_auth/src/sign_in/model/sign_in_phase.dart';

/// Everything the sign-in UI renders. Built by `SignInViewModel`; widgets
/// only read it.
///
/// Transient UI state that is never serialized, so it has no
/// `toJson`/`fromJson`.
class SignInState {
  const SignInState({
    required this.phase,
    this.isBusy = false,
    this.feedback = SignInFeedback.none,
    this.emailError = FieldError.none,
    this.passwordError = FieldError.none,
    this.repeatedPasswordError = FieldError.none,
    this.codeError = FieldError.none,
    this.rememberedEmail = '',
    this.canGoBack = false,
    this.isSignUpOffered = false,
    this.isPasskeySignInOffered = false,
    this.isTemporaryAccessPassOffered = false,
    this.isAccessCodeOffered = false,
    this.isMagicLinkOffered = false,
    this.copy = const SignInCopy(),
    this.policyUri,
    this.tosUri,
  });

  final SignInPhase phase;

  /// A request is in flight: the thin progress bar shows and actions are
  /// disabled.
  final bool isBusy;
  final SignInFeedback feedback;
  final FieldError emailError;
  final FieldError passwordError;

  /// The new password typed again, on [SignInNewPasswordEntry].
  final FieldError repeatedPasswordError;
  final FieldError codeError;

  /// The last email the user typed, to prefill the next form.
  final String rememberedEmail;

  /// A "Back" action leads to the method picker.
  final bool canGoBack;
  final bool isSignUpOffered;

  /// Shows "Sign in with a passkey" on the method picker
  /// ([SignInConfiguration.isPasskeySignInOffered]).
  final bool isPasskeySignInOffered;

  /// Shows "Use a temporary access pass"
  /// ([SignInConfiguration.isTemporaryAccessPassOffered]).
  final bool isTemporaryAccessPassOffered;

  /// Shows "I have an access code": the app opts in
  /// ([SignInConfiguration.isAccessCodeOffered]) **and** the server lists
  /// `access_code` for this client (`ClientLoginOptions.isAccessCodeOffered`).
  /// `false` until the login options arrive.
  final bool isAccessCodeOffered;

  /// Shows "Email me a sign-in link instead" on the email-OTP step
  /// (`ClientLoginOptions.isMagicLinkOffered` — server-driven only, no
  /// matching `SignInConfiguration` flag: a company turns this on per
  /// client, not per app build).
  final bool isMagicLinkOffered;
  final SignInCopy copy;

  /// The company's privacy-policy page
  /// (`ClientLoginOptions.policyUri` — server-driven only), shown in the
  /// footer below the current step. `null` hides that link.
  final Uri? policyUri;

  /// The company's terms-of-service page
  /// (`ClientLoginOptions.tosUri` — server-driven only), shown in the
  /// footer below the current step. `null` hides that link.
  final Uri? tosUri;

  SignInState copyWith({
    SignInPhase? phase,
    bool? isBusy,
    SignInFeedback? feedback,
    FieldError? emailError,
    FieldError? passwordError,
    FieldError? repeatedPasswordError,
    FieldError? codeError,
    String? rememberedEmail,
    bool? canGoBack,
    bool? isSignUpOffered,
    bool? isPasskeySignInOffered,
    bool? isTemporaryAccessPassOffered,
    bool? isAccessCodeOffered,
    bool? isMagicLinkOffered,
    SignInCopy? copy,
    Uri? policyUri,
    Uri? tosUri,
  }) => SignInState(
    phase: phase ?? this.phase,
    isBusy: isBusy ?? this.isBusy,
    feedback: feedback ?? this.feedback,
    emailError: emailError ?? this.emailError,
    passwordError: passwordError ?? this.passwordError,
    repeatedPasswordError: repeatedPasswordError ?? this.repeatedPasswordError,
    codeError: codeError ?? this.codeError,
    rememberedEmail: rememberedEmail ?? this.rememberedEmail,
    canGoBack: canGoBack ?? this.canGoBack,
    isSignUpOffered: isSignUpOffered ?? this.isSignUpOffered,
    isPasskeySignInOffered:
        isPasskeySignInOffered ?? this.isPasskeySignInOffered,
    isTemporaryAccessPassOffered:
        isTemporaryAccessPassOffered ?? this.isTemporaryAccessPassOffered,
    isAccessCodeOffered: isAccessCodeOffered ?? this.isAccessCodeOffered,
    isMagicLinkOffered: isMagicLinkOffered ?? this.isMagicLinkOffered,
    copy: copy ?? this.copy,
    policyUri: policyUri ?? this.policyUri,
    tosUri: tosUri ?? this.tosUri,
  );

  /// The same screen with no message and no field errors.
  SignInState withoutMessages() => copyWith(
    feedback: SignInFeedback.none,
    emailError: FieldError.none,
    passwordError: FieldError.none,
    repeatedPasswordError: FieldError.none,
    codeError: FieldError.none,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SignInState &&
          phase == other.phase &&
          isBusy == other.isBusy &&
          feedback == other.feedback &&
          emailError == other.emailError &&
          passwordError == other.passwordError &&
          repeatedPasswordError == other.repeatedPasswordError &&
          codeError == other.codeError &&
          rememberedEmail == other.rememberedEmail &&
          canGoBack == other.canGoBack &&
          isSignUpOffered == other.isSignUpOffered &&
          isPasskeySignInOffered == other.isPasskeySignInOffered &&
          isTemporaryAccessPassOffered == other.isTemporaryAccessPassOffered &&
          isAccessCodeOffered == other.isAccessCodeOffered &&
          isMagicLinkOffered == other.isMagicLinkOffered &&
          copy == other.copy &&
          policyUri == other.policyUri &&
          tosUri == other.tosUri;

  @override
  int get hashCode => Object.hash(
    phase,
    isBusy,
    feedback,
    emailError,
    passwordError,
    repeatedPasswordError,
    codeError,
    rememberedEmail,
    canGoBack,
    isSignUpOffered,
    isPasskeySignInOffered,
    isTemporaryAccessPassOffered,
    isAccessCodeOffered,
    isMagicLinkOffered,
    copy,
    policyUri,
    tosUri,
  );
}
