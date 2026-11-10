import 'package:loginflow_auth/src/core/json/json_field_reader.dart';

/// The `device_push` or `device_qr` object of a sign-in on another device
/// (`doc/server-contract.md` §21): the request's answer carries what the
/// page shows ([number] or [qrUri]); a poll that is still undecided carries
/// only the timing.
class DeviceSignInDetails {
  /// Creates a [DeviceSignInDetails].
  const DeviceSignInDetails({
    this.number,
    this.qrUri,
    this.expiresIn,
    this.interval,
  });

  /// Reads a [DeviceSignInDetails] from its JSON form ([toJson]).
  factory DeviceSignInDetails.fromJson(Map<String, Object?> json) {
    final qrUri = json.optionalString('qr_uri');
    final expiresIn = json.optionalInt('expires_in');
    final interval = json.optionalInt('interval');
    return DeviceSignInDetails(
      number: json.optionalInt('number'),
      qrUri: qrUri == null ? null : Uri.parse(qrUri),
      expiresIn: expiresIn == null ? null : Duration(seconds: expiresIn),
      interval: interval == null ? null : Duration(seconds: interval),
    );
  }

  /// The two-digit number of a phone approval (`device_push`), on the
  /// request's answer only.
  final int? number;

  /// What the QR encodes (`device_qr`):
  /// `https://<company passkey host>/qr/<request_id>#<secret>`, on the
  /// request's answer only.
  final Uri? qrUri;

  /// How long the request still lives.
  final Duration? expiresIn;

  /// The wait between two polls (RFC 8628 §3.2).
  final Duration? interval;

  /// A copy of this [DeviceSignInDetails] with the given fields replaced.
  DeviceSignInDetails copyWith({
    int? number,
    Uri? qrUri,
    Duration? expiresIn,
    Duration? interval,
  }) => DeviceSignInDetails(
    number: number ?? this.number,
    qrUri: qrUri ?? this.qrUri,
    expiresIn: expiresIn ?? this.expiresIn,
    interval: interval ?? this.interval,
  );

  /// The JSON form of this [DeviceSignInDetails], read back by
  /// [DeviceSignInDetails.fromJson].
  Map<String, Object?> toJson() => <String, Object?>{
    'number': ?number,
    'qr_uri': ?qrUri?.toString(),
    'expires_in': ?expiresIn?.inSeconds,
    'interval': ?interval?.inSeconds,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DeviceSignInDetails &&
          number == other.number &&
          qrUri == other.qrUri &&
          expiresIn == other.expiresIn &&
          interval == other.interval;

  @override
  int get hashCode => Object.hash(number, qrUri, expiresIn, interval);

  @override
  String toString() =>
      'DeviceSignInDetails(number: $number, qrUri: <redacted>, '
      'expiresIn: $expiresIn, interval: $interval)';
}

/// A poll of a sign-in on another device that is still undecided
/// (RFC 8628 §3.5): the `error` of its `403`.
enum DevicePollStatus {
  /// Nobody answered yet: poll again after the interval.
  pending('authorization_pending'),

  /// Polled too soon: the interval grows by 5 s, for good.
  slowDown('slow_down');

  const DevicePollStatus(this.wireName);

  /// The name of this value on the wire.
  final String wireName;

  /// The value whose [wireName] is the given name, or `null` for any other.
  static DevicePollStatus? fromWireName(String? value) {
    for (final status in values) {
      if (status.wireName == value) {
        return status;
      }
    }
    return null;
  }
}
