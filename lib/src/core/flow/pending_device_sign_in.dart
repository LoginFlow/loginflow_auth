import 'package:loginflow_auth/src/core/protocol/challenge/challenge_step.dart';
import 'package:loginflow_auth/src/core/state/phone_approval.dart';
import 'package:loginflow_auth/src/core/state/qr_sign_in.dart';

/// A sign-in on another device the library is polling
/// (`doc/server-contract.md` §21): what the page shows and the current
/// polling interval.
///
/// Internal flow state, never persisted, so no `toJson`/`fromJson`.
class PendingDeviceSignIn {
  const PendingDeviceSignIn({
    required this.step,
    required this.expiresAt,
    required this.interval,
    this.phoneApproval,
    this.qrSignIn,
  });

  /// [ChallengeStep.devicePush] or [ChallengeStep.deviceQr].
  final ChallengeStep step;

  /// When the request stops being answerable (UTC).
  final DateTime expiresAt;

  /// The wait before the next poll; grows by 5 s on every `slow_down`.
  final Duration interval;

  /// What a phone approval shows; `null` for a QR.
  final PhoneApproval? phoneApproval;

  /// What a QR sign-in shows; `null` for a phone approval.
  final QrSignIn? qrSignIn;

  PendingDeviceSignIn copyWith({
    ChallengeStep? step,
    DateTime? expiresAt,
    Duration? interval,
    PhoneApproval? phoneApproval,
    QrSignIn? qrSignIn,
  }) => PendingDeviceSignIn(
    step: step ?? this.step,
    expiresAt: expiresAt ?? this.expiresAt,
    interval: interval ?? this.interval,
    phoneApproval: phoneApproval ?? this.phoneApproval,
    qrSignIn: qrSignIn ?? this.qrSignIn,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PendingDeviceSignIn &&
          step == other.step &&
          expiresAt == other.expiresAt &&
          interval == other.interval &&
          phoneApproval == other.phoneApproval &&
          qrSignIn == other.qrSignIn;

  @override
  int get hashCode =>
      Object.hash(step, expiresAt, interval, phoneApproval, qrSignIn);

  @override
  String toString() => 'PendingDeviceSignIn(${step.wireName})';
}
