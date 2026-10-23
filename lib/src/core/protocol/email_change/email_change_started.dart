import 'package:loginflow_auth/src/core/json/json_field_reader.dart';

/// The answer of `LoginFlowAuth.startEmailChange`
/// (`POST /v1/app/email-change`, `doc/server-contract.md` §19): a code went
/// to the new address and, when [confirmCurrent], another one to the
/// current address. The answer is the same whether or not the new address
/// can be used: when no code reaches it, it cannot.
class EmailChangeStarted {
  const EmailChangeStarted({
    required this.expiresAt,
    required this.confirmCurrent,
  });

  factory EmailChangeStarted.fromJson(Map<String, Object?> json) =>
      EmailChangeStarted(
        expiresAt: json.requireUtcDateTime('expires_at'),
        confirmCurrent: json.requireBool('confirm_current'),
      );

  /// When the codes stop working (UTC).
  final DateTime expiresAt;

  /// The account has no second factor: the confirmation needs the code sent
  /// to the CURRENT address too (`currentCode` of
  /// `LoginFlowAuth.confirmEmailChange`).
  final bool confirmCurrent;

  EmailChangeStarted copyWith({DateTime? expiresAt, bool? confirmCurrent}) =>
      EmailChangeStarted(
        expiresAt: expiresAt ?? this.expiresAt,
        confirmCurrent: confirmCurrent ?? this.confirmCurrent,
      );

  Map<String, Object?> toJson() => <String, Object?>{
    'expires_at': expiresAt.toUtc().toIso8601String(),
    'confirm_current': confirmCurrent,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is EmailChangeStarted &&
          expiresAt == other.expiresAt &&
          confirmCurrent == other.confirmCurrent;

  @override
  int get hashCode => Object.hash(expiresAt, confirmCurrent);
}
