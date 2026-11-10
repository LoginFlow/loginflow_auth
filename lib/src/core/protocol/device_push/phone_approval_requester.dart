import 'package:loginflow_auth/src/core/json/json_field_reader.dart';

/// Where a sign-in by phone approval comes from: the web page that asked to
/// sign in (`requester` of `GET /v1/user/device-push/pending`,
/// `doc/server-contract.md` §21). Show it so the person can tell whether it
/// was them; LoginFlow has no geo-IP location to add.
class PhoneApprovalRequester {
  /// Creates a [PhoneApprovalRequester].
  const PhoneApprovalRequester({this.device, this.ipAddress});

  /// Reads a [PhoneApprovalRequester] from its JSON form ([toJson]).
  factory PhoneApprovalRequester.fromJson(Map<String, Object?> json) =>
      PhoneApprovalRequester(
        device: json.optionalString('device'),
        ipAddress: json.optionalString('ip_address'),
      );

  /// `"<browser> on <system>"` read from the page's `User-Agent`
  /// (`Chrome on macOS`), `null` when it names neither.
  final String? device;

  /// The page's address as LoginFlow saw it, `null` when unknown.
  final String? ipAddress;

  /// A copy of this [PhoneApprovalRequester] with the given fields replaced.
  PhoneApprovalRequester copyWith({String? device, String? ipAddress}) =>
      PhoneApprovalRequester(
        device: device ?? this.device,
        ipAddress: ipAddress ?? this.ipAddress,
      );

  /// The JSON form of this [PhoneApprovalRequester], read back by [PhoneApprovalRequester.fromJson].
  Map<String, Object?> toJson() => <String, Object?>{
    'device': ?device,
    'ip_address': ?ipAddress,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PhoneApprovalRequester &&
          device == other.device &&
          ipAddress == other.ipAddress;

  @override
  int get hashCode => Object.hash(device, ipAddress);
}
