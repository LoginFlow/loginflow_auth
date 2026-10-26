import 'package:loginflow_auth/src/core/json/json_field_reader.dart';

/// The answer of `LoginFlowAuth.totpStatus` (`GET /v1/user/totp/status`,
/// `doc/server-contract.md` §20): whether the signed-in person signs in
/// with an authenticator app as their second factor.
class TotpStatus {
  /// Creates a [TotpStatus].
  const TotpStatus({required this.isEnabled, this.verifiedAt});

  /// Reads a [TotpStatus] from its JSON form ([toJson]).
  factory TotpStatus.fromJson(Map<String, Object?> json) => TotpStatus(
    isEnabled: json.requireBool('enabled'),
    verifiedAt: json.optionalUtcDateTime('verified_at'),
  );

  /// Whether the authenticator app is on: LoginFlow asks for its code at
  /// sign-in and accepts it for a strong step-up.
  final bool isEnabled;

  /// When the enrollment was confirmed (UTC); `null` when it is off.
  final DateTime? verifiedAt;

  /// A copy of this [TotpStatus] with the given fields replaced.
  TotpStatus copyWith({bool? isEnabled, DateTime? verifiedAt}) => TotpStatus(
    isEnabled: isEnabled ?? this.isEnabled,
    verifiedAt: verifiedAt ?? this.verifiedAt,
  );

  /// The JSON form of this [TotpStatus], read back by [TotpStatus.fromJson].
  Map<String, Object?> toJson() => <String, Object?>{
    'enabled': isEnabled,
    'verified_at': verifiedAt?.toUtc().toIso8601String(),
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TotpStatus &&
          isEnabled == other.isEnabled &&
          verifiedAt == other.verifiedAt;

  @override
  int get hashCode => Object.hash(isEnabled, verifiedAt);
}
