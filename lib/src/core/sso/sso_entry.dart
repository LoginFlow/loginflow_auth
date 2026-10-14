import 'package:loginflow_auth/src/core/json/json_field_reader.dart';

/// What same-publisher apps share for OpenID Connect Native SSO (§2): the
/// device secret and the ID token bound to it through `ds_hash`.
///
/// Refresh tokens are never shared; each app keeps its own
/// (OpenID Connect Native SSO §4; `doc/decisions.md` D11).
class SsoEntry {
  const SsoEntry({
    required this.issuer,
    required this.deviceSecret,
    required this.idToken,
    required this.updatedAt,
  });

  factory SsoEntry.fromJson(Map<String, Object?> json) => SsoEntry(
    issuer: json.requireString('issuer'),
    deviceSecret: json.requireString('device_secret'),
    idToken: json.requireString('id_token'),
    updatedAt: DateTime.fromMillisecondsSinceEpoch(
      json.requireInt('updated_at'),
      isUtc: true,
    ),
  );

  final String issuer;
  final String deviceSecret;
  final String idToken;

  /// When the entry was written; with several copies (Android providers) the
  /// newest wins.
  final DateTime updatedAt;

  SsoEntry copyWith({
    String? issuer,
    String? deviceSecret,
    String? idToken,
    DateTime? updatedAt,
  }) => SsoEntry(
    issuer: issuer ?? this.issuer,
    deviceSecret: deviceSecret ?? this.deviceSecret,
    idToken: idToken ?? this.idToken,
    updatedAt: updatedAt ?? this.updatedAt,
  );

  Map<String, Object?> toJson() => <String, Object?>{
    'issuer': issuer,
    'device_secret': deviceSecret,
    'id_token': idToken,
    'updated_at': updatedAt.millisecondsSinceEpoch,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SsoEntry &&
          issuer == other.issuer &&
          deviceSecret == other.deviceSecret &&
          idToken == other.idToken &&
          updatedAt == other.updatedAt;

  @override
  int get hashCode => Object.hash(issuer, deviceSecret, idToken, updatedAt);

  @override
  String toString() => 'SsoEntry(issuer: $issuer, updatedAt: $updatedAt)';
}
