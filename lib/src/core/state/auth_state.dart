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
  const AuthInitializing();

  @override
  bool operator ==(Object other) => other is AuthInitializing;

  @override
  int get hashCode => (AuthInitializing).hashCode;
}

/// No session.
final class SignedOut extends AuthState {
  const SignedOut({this.reason = SignOutReason.none, this.loginHint});

  final SignOutReason reason;

  /// Identifier to prefill, e.g. after Native SSO needed interaction.
  final String? loginHint;

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
  const SsoAvailable({required this.candidate});

  final SsoCandidate candidate;

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
  const ChallengeRequired({required this.prompt, required this.purpose});

  final ChallengePrompt prompt;
  final ChallengePurpose purpose;

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
  const AwaitingBrowser();

  @override
  bool operator ==(Object other) => other is AwaitingBrowser;

  @override
  int get hashCode => (AwaitingBrowser).hashCode;
}

/// A user is signed in.
final class SignedIn extends AuthState {
  const SignedIn({required this.session});

  final LoginFlowSession session;

  SignedIn copyWith({LoginFlowSession? session}) =>
      SignedIn(session: session ?? this.session);

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is SignedIn && session == other.session;

  @override
  int get hashCode => Object.hash(SignedIn, session);
}
