import 'package:loginflow_auth/src/core/json/json_field_reader.dart';

/// A phone approval waiting on the person's phone
/// (`LoginFlowAuth.requestPhoneApproval`, `doc/server-contract.md` §21):
/// show [number] large, with "Open your app and choose this number", and
/// count down to [expiresAt]. The library polls until it is decided.
class PhoneApproval {
  /// Creates a [PhoneApproval].
  const PhoneApproval({required this.number, required this.expiresAt});

  /// Reads a [PhoneApproval] from its JSON form ([toJson]).
  factory PhoneApproval.fromJson(Map<String, Object?> json) => PhoneApproval(
    number: json.requireInt('number'),
    expiresAt: json.requireUtcDateTime('expires_at'),
  );

  /// The two-digit number (10-99) the person picks on the phone.
  final int number;

  /// When the request stops being answerable (UTC), on this library's
  /// clock.
  final DateTime expiresAt;

  /// A copy of this [PhoneApproval] with the given fields replaced.
  PhoneApproval copyWith({int? number, DateTime? expiresAt}) => PhoneApproval(
    number: number ?? this.number,
    expiresAt: expiresAt ?? this.expiresAt,
  );

  /// The JSON form of this [PhoneApproval], read back by
  /// [PhoneApproval.fromJson].
  Map<String, Object?> toJson() => <String, Object?>{
    'number': number,
    'expires_at': expiresAt.toUtc().toIso8601String(),
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PhoneApproval &&
          number == other.number &&
          expiresAt == other.expiresAt;

  @override
  int get hashCode => Object.hash(PhoneApproval, number, expiresAt);
}
