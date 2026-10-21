import 'package:loginflow_auth/src/sign_in/model/passkeys_feedback.dart';
import 'package:loginflow_auth/src/sign_in/model/passkeys_phase.dart';

/// Everything the passkey manager renders. Built by `PasskeysViewModel`;
/// widgets only read it.
///
/// Transient UI state that is never serialized, so it has no
/// `toJson`/`fromJson`.
class PasskeysState {
  const PasskeysState({
    required this.phase,
    this.isBusy = false,
    this.feedback = PasskeysFeedback.none,
    this.isEnrollmentOffered = false,
  });

  final PasskeysPhase phase;

  /// A request or a passkey ceremony is in flight: the thin progress bar
  /// shows and actions are disabled.
  final bool isBusy;
  final PasskeysFeedback feedback;

  /// "Add a passkey" is shown. `false` for an access-code `device` subject:
  /// a shared device has no single owner to bind a passkey to.
  final bool isEnrollmentOffered;

  PasskeysState copyWith({
    PasskeysPhase? phase,
    bool? isBusy,
    PasskeysFeedback? feedback,
    bool? isEnrollmentOffered,
  }) => PasskeysState(
    phase: phase ?? this.phase,
    isBusy: isBusy ?? this.isBusy,
    feedback: feedback ?? this.feedback,
    isEnrollmentOffered: isEnrollmentOffered ?? this.isEnrollmentOffered,
  );

  /// The same screen with no message.
  PasskeysState withoutMessages() => copyWith(feedback: PasskeysFeedback.none);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PasskeysState &&
          phase == other.phase &&
          isBusy == other.isBusy &&
          feedback == other.feedback &&
          isEnrollmentOffered == other.isEnrollmentOffered;

  @override
  int get hashCode => Object.hash(phase, isBusy, feedback, isEnrollmentOffered);
}
