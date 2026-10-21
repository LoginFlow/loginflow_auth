import 'package:loginflow_auth/src/core/json/list_equality.dart';
import 'package:loginflow_auth/src/core/session/login_flow_session.dart';
import 'package:loginflow_auth/src/core/sso/sso_candidate.dart';
import 'package:loginflow_auth/src/sign_in/model/auth_method.dart';

/// Which screen of the sign-in flow is showing.
///
/// Phases are transient UI state rebuilt from the authentication state; they
/// are never serialized, so they have no `toJson`/`fromJson`.
sealed class SignInPhase {
  const SignInPhase();
}

/// `LoginFlowSignInSetup.install` was not called.
final class SignInNotConfigured extends SignInPhase {
  const SignInNotConfigured();

  @override
  bool operator ==(Object other) => other is SignInNotConfigured;

  @override
  int get hashCode => (SignInNotConfigured).hashCode;
}

/// Reading the methods the server enables for this client.
final class SignInLoadingOptions extends SignInPhase {
  const SignInLoadingOptions();

  @override
  bool operator ==(Object other) => other is SignInLoadingOptions;

  @override
  int get hashCode => (SignInLoadingOptions).hashCode;
}

/// The server's login options could not be read; nothing unverified is shown.
final class SignInOptionsUnavailable extends SignInPhase {
  const SignInOptionsUnavailable();

  @override
  bool operator ==(Object other) => other is SignInOptionsUnavailable;

  @override
  int get hashCode => (SignInOptionsUnavailable).hashCode;
}

/// None of the configured methods is enabled on the server.
final class SignInNoMethods extends SignInPhase {
  const SignInNoMethods();

  @override
  bool operator ==(Object other) => other is SignInNoMethods;

  @override
  int get hashCode => (SignInNoMethods).hashCode;
}

/// Several methods: the user picks one.
final class SignInChoosingMethod extends SignInPhase {
  const SignInChoosingMethod({required this.methods});

  final List<AuthMethod> methods;

  SignInChoosingMethod copyWith({List<AuthMethod>? methods}) =>
      SignInChoosingMethod(methods: methods ?? this.methods);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SignInChoosingMethod && methods.hasSameValues(other.methods);

  @override
  int get hashCode => methods.valuesHash;
}

/// Email and password form.
final class SignInPasswordEntry extends SignInPhase {
  const SignInPasswordEntry({
    required this.isForgotPasswordShown,
    this.isIdentifierLocked = false,
    this.isEmailCodeOffered = false,
  });

  final bool isForgotPasswordShown;

  /// The server already knows the user (re-authentication); only the
  /// password is asked.
  final bool isIdentifierLocked;

  /// Shows "Email me a code" instead of the password
  /// (`SignInViewModel.useEmailCode`): a re-authentication the client
  /// may also answer with an email code.
  final bool isEmailCodeOffered;

  SignInPasswordEntry copyWith({
    bool? isForgotPasswordShown,
    bool? isIdentifierLocked,
    bool? isEmailCodeOffered,
  }) => SignInPasswordEntry(
    isForgotPasswordShown: isForgotPasswordShown ?? this.isForgotPasswordShown,
    isIdentifierLocked: isIdentifierLocked ?? this.isIdentifierLocked,
    isEmailCodeOffered: isEmailCodeOffered ?? this.isEmailCodeOffered,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SignInPasswordEntry &&
          isForgotPasswordShown == other.isForgotPasswordShown &&
          isIdentifierLocked == other.isIdentifierLocked &&
          isEmailCodeOffered == other.isEmailCodeOffered;

  @override
  int get hashCode => Object.hash(
    isForgotPasswordShown,
    isIdentifierLocked,
    isEmailCodeOffered,
  );
}

/// Email form before the one-time code is sent.
final class SignInEmailEntry extends SignInPhase {
  const SignInEmailEntry();

  @override
  bool operator ==(Object other) => other is SignInEmailEntry;

  @override
  int get hashCode => (SignInEmailEntry).hashCode;
}

/// One-time code form.
final class SignInOtpEntry extends SignInPhase {
  const SignInOtpEntry({required this.email, required this.resendSecondsLeft});

  final String email;

  /// 0 when "Resend code" is enabled.
  final int resendSecondsLeft;

  bool get canResend => resendSecondsLeft == 0;

  SignInOtpEntry copyWith({String? email, int? resendSecondsLeft}) =>
      SignInOtpEntry(
        email: email ?? this.email,
        resendSecondsLeft: resendSecondsLeft ?? this.resendSecondsLeft,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SignInOtpEntry &&
          email == other.email &&
          resendSecondsLeft == other.resendSecondsLeft;

  @override
  int get hashCode => Object.hash(email, resendSecondsLeft);
}

/// TOTP (or recovery code) form, shown whenever the server asks for it.
final class SignInTotpEntry extends SignInPhase {
  const SignInTotpEntry({
    required this.isRecoveryCode,
    required this.canUseRecoveryCode,
  });

  final bool isRecoveryCode;
  final bool canUseRecoveryCode;

  SignInTotpEntry copyWith({bool? isRecoveryCode, bool? canUseRecoveryCode}) =>
      SignInTotpEntry(
        isRecoveryCode: isRecoveryCode ?? this.isRecoveryCode,
        canUseRecoveryCode: canUseRecoveryCode ?? this.canUseRecoveryCode,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SignInTotpEntry &&
          isRecoveryCode == other.isRecoveryCode &&
          canUseRecoveryCode == other.canUseRecoveryCode;

  @override
  int get hashCode => Object.hash(isRecoveryCode, canUseRecoveryCode);
}

/// Temporary Access Pass entry: an admin-issued, single-use recovery code
/// (`doc/server-contract.md` §5.7). The user navigates here directly
/// (`SignInViewModel.useTemporaryAccessPass`) — the server never prompts
/// for this method, so [isIdentifierLocked] is `true` only on the rare
/// defensive path where a `ChallengeStep.temporaryAccessPass` `next`
/// arrives with the account already identified by the `auth_session`.
final class SignInTemporaryAccessPassEntry extends SignInPhase {
  const SignInTemporaryAccessPassEntry({this.isIdentifierLocked = false});

  final bool isIdentifierLocked;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SignInTemporaryAccessPassEntry &&
          isIdentifierLocked == other.isIdentifierLocked;

  @override
  int get hashCode => Object.hash(SignInTemporaryAccessPassEntry, isIdentifierLocked);
}

/// Access-code entry: a single-use code the tenant's backend issued
/// (`doc/server-contract.md` §16). Reached through
/// `SignInViewModel.useAccessCode`, or the entry screen itself when the app
/// offers no other method. A local navigation: the server never prompts
/// for this method.
final class SignInAccessCodeEntry extends SignInPhase {
  const SignInAccessCodeEntry();

  @override
  bool operator ==(Object other) => other is SignInAccessCodeEntry;

  @override
  int get hashCode => (SignInAccessCodeEntry).hashCode;
}

/// The system browser is open.
final class SignInAwaitingBrowser extends SignInPhase {
  const SignInAwaitingBrowser();

  @override
  bool operator ==(Object other) => other is SignInAwaitingBrowser;

  @override
  int get hashCode => (SignInAwaitingBrowser).hashCode;
}

/// "Continue as …" with the Native SSO session of a sibling app.
final class SignInSsoConfirm extends SignInPhase {
  const SignInSsoConfirm({required this.candidate});

  final SsoCandidate candidate;

  SignInSsoConfirm copyWith({SsoCandidate? candidate}) =>
      SignInSsoConfirm(candidate: candidate ?? this.candidate);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SignInSsoConfirm && candidate == other.candidate;

  @override
  int get hashCode => candidate.hashCode;
}

/// HTTP 429: too many attempts; waits [secondsLeft].
final class SignInLockedOut extends SignInPhase {
  const SignInLockedOut({required this.secondsLeft});

  final int secondsLeft;

  SignInLockedOut copyWith({int? secondsLeft}) =>
      SignInLockedOut(secondsLeft: secondsLeft ?? this.secondsLeft);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SignInLockedOut && secondsLeft == other.secondsLeft;

  @override
  int get hashCode => secondsLeft.hashCode;
}

/// Signed in.
final class SignInCompleted extends SignInPhase {
  const SignInCompleted({required this.session});

  final LoginFlowSession session;

  SignInCompleted copyWith({LoginFlowSession? session}) =>
      SignInCompleted(session: session ?? this.session);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SignInCompleted && session == other.session;

  @override
  int get hashCode => session.hashCode;
}
