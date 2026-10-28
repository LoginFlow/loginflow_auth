import 'package:loginflow_auth/src/core/session/login_flow_session.dart';
import 'package:loginflow_auth/src/core/sso/sso_candidate.dart';
import 'package:loginflow_auth/src/core/state/challenge_prompt.dart';
import 'package:loginflow_auth/src/core/state/challenge_purpose.dart';
import 'package:loginflow_auth/src/core/state/sign_out_reason.dart';

/// The authentication state of one app, published by
/// `LoginFlowAuth.states`.
///
/// States are transient: they are rebuilt from storage at start-up and never
/// serialized themselves, so they have no `toJson`/`fromJson`.
sealed class AuthState {
  const AuthState();
}

/// Before `LoginFlowAuth.initialize` finished reading storage.
final class AuthInitializing extends AuthState {
  /// Creates an [AuthInitializing].
  const AuthInitializing();

  @override
  bool operator ==(Object other) => other is AuthInitializing;

  @override
  int get hashCode => (AuthInitializing).hashCode;
}

/// No session.
final class SignedOut extends AuthState {
  /// Creates a [SignedOut].
  const SignedOut({this.reason = SignOutReason.none, this.loginHint});

  /// Why nobody is signed in.
  final SignOutReason reason;

  /// Identifier to prefill, e.g. after Native SSO needed interaction.
  final String? loginHint;

  /// A copy of this [SignedOut] with the given fields replaced.
  SignedOut copyWith({SignOutReason? reason, String? loginHint}) => SignedOut(
    reason: reason ?? this.reason,
    loginHint: loginHint ?? this.loginHint,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SignedOut &&
          reason == other.reason &&
          loginHint == other.loginHint;

  @override
  int get hashCode => Object.hash(SignedOut, reason, loginHint);
}

/// Another app of the publisher is signed in on this device; the user can
/// continue as [candidate] without entering credentials.
final class SsoAvailable extends AuthState {
  /// Creates a [SsoAvailable].
  const SsoAvailable({required this.candidate});

  /// Whose shared session can be continued.
  final SsoCandidate candidate;

  /// A copy of this [SsoAvailable] with the given fields replaced.
  SsoAvailable copyWith({SsoCandidate? candidate}) =>
      SsoAvailable(candidate: candidate ?? this.candidate);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SsoAvailable && candidate == other.candidate;

  @override
  int get hashCode => Object.hash(SsoAvailable, candidate);
}

/// The server needs one more step from the user.
final class ChallengeRequired extends AuthState {
  /// Creates a [ChallengeRequired].
  const ChallengeRequired({required this.prompt, required this.purpose});

  /// What to ask the user.
  final ChallengePrompt prompt;

  /// Whether this is a sign-in, a step-up or a re-authentication.
  final ChallengePurpose purpose;

  /// A copy of this [ChallengeRequired] with the given fields replaced.
  ChallengeRequired copyWith({
    ChallengePrompt? prompt,
    ChallengePurpose? purpose,
  }) => ChallengeRequired(
    prompt: prompt ?? this.prompt,
    purpose: purpose ?? this.purpose,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ChallengeRequired &&
          prompt == other.prompt &&
          purpose == other.purpose;

  @override
  int get hashCode => Object.hash(ChallengeRequired, prompt, purpose);
}

/// The system browser is open (or, on the web, the page is navigating away).
final class AwaitingBrowser extends AuthState {
  /// Creates an [AwaitingBrowser].
  const AwaitingBrowser();

  @override
  bool operator ==(Object other) => other is AwaitingBrowser;

  @override
  int get hashCode => (AwaitingBrowser).hashCode;
}

/// An in-app password reset waits for the code emailed to [email]
/// (`LoginFlowAuth.startPasswordReset`). The server answers the same for an
/// address with no account, and sends nothing then; say "if this email has
/// an account, we sent it a code".
final class AwaitingResetCode extends AuthState {
  /// Creates an [AwaitingResetCode].
  const AwaitingResetCode({required this.email});

  /// The address the code was sent to.
  final String email;

  /// A copy of this [AwaitingResetCode] with the given fields replaced.
  AwaitingResetCode copyWith({String? email}) =>
      AwaitingResetCode(email: email ?? this.email);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AwaitingResetCode && email == other.email;

  @override
  int get hashCode => Object.hash(AwaitingResetCode, email);
}

/// The reset code was accepted: the person behind [email] is identified and
/// the library holds their session, but nobody is signed in until
/// `LoginFlowAuth.setNewPassword` succeeds. Nothing is stored meanwhile.
final class AwaitingNewPassword extends AuthState {
  /// Creates an [AwaitingNewPassword].
  const AwaitingNewPassword({required this.email});

  /// The address the reset started with, for display.
  final String email;

  /// A copy of this [AwaitingNewPassword] with the given fields replaced.
  AwaitingNewPassword copyWith({String? email}) =>
      AwaitingNewPassword(email: email ?? this.email);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AwaitingNewPassword && email == other.email;

  @override
  int get hashCode => Object.hash(AwaitingNewPassword, email);
}

/// A user is signed in.
final class SignedIn extends AuthState {
  /// Creates a [SignedIn].
  const SignedIn({required this.session});

  /// The signed-in session.
  final LoginFlowSession session;

  /// A copy of this [SignedIn] with the given fields replaced.
  SignedIn copyWith({LoginFlowSession? session}) =>
      SignedIn(session: session ?? this.session);

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is SignedIn && session == other.session;

  @override
  int get hashCode => Object.hash(SignedIn, session);
}
