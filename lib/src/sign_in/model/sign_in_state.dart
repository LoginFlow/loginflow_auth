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
    this.codeError = FieldError.none,
    this.rememberedEmail = '',
    this.canGoBack = false,
    this.isSignUpOffered = false,
    this.copy = const SignInCopy(),
  });

  final SignInPhase phase;

  /// A request is in flight: the thin progress bar shows and actions are
  /// disabled.
  final bool isBusy;
  final SignInFeedback feedback;
  final FieldError emailError;
  final FieldError passwordError;
  final FieldError codeError;

  /// The last email the user typed, to prefill the next form.
  final String rememberedEmail;

  /// A "Back" action leads to the method picker.
  final bool canGoBack;
  final bool isSignUpOffered;
  final SignInCopy copy;

  SignInState copyWith({
    SignInPhase? phase,
    bool? isBusy,
    SignInFeedback? feedback,
    FieldError? emailError,
    FieldError? passwordError,
    FieldError? codeError,
    String? rememberedEmail,
    bool? canGoBack,
    bool? isSignUpOffered,
    SignInCopy? copy,
  }) => SignInState(
    phase: phase ?? this.phase,
    isBusy: isBusy ?? this.isBusy,
    feedback: feedback ?? this.feedback,
    emailError: emailError ?? this.emailError,
    passwordError: passwordError ?? this.passwordError,
    codeError: codeError ?? this.codeError,
    rememberedEmail: rememberedEmail ?? this.rememberedEmail,
    canGoBack: canGoBack ?? this.canGoBack,
    isSignUpOffered: isSignUpOffered ?? this.isSignUpOffered,
    copy: copy ?? this.copy,
  );

  /// The same screen with no message and no field errors.
  SignInState withoutMessages() => copyWith(
    feedback: SignInFeedback.none,
    emailError: FieldError.none,
    passwordError: FieldError.none,
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
          codeError == other.codeError &&
          rememberedEmail == other.rememberedEmail &&
          canGoBack == other.canGoBack &&
          isSignUpOffered == other.isSignUpOffered &&
          copy == other.copy;

  @override
  int get hashCode => Object.hash(
    phase,
    isBusy,
    feedback,
    emailError,
    passwordError,
    codeError,
    rememberedEmail,
    canGoBack,
    isSignUpOffered,
    copy,
  );
}
