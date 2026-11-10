import 'package:loginflow_auth/src/core/json/json_field_reader.dart';

/// A sign-in QR on screen (`LoginFlowAuth.requestQrSignIn`,
/// `doc/server-contract.md` §21): render [qrUri] as a QR and count down to
/// [expiresAt]. A person signed in to an app of the same company scans it
/// and approves; the library polls until it is decided.
class QrSignIn {
  /// Creates a [QrSignIn].
  const QrSignIn({required this.qrUri, required this.expiresAt});

  /// Reads a [QrSignIn] from its JSON form ([toJson]).
  factory QrSignIn.fromJson(Map<String, Object?> json) => QrSignIn(
    qrUri: Uri.parse(json.requireString('qr_uri')),
    expiresAt: json.requireUtcDateTime('expires_at'),
  );

  /// What the QR encodes: `https://<company passkey host>/qr/<id>#<secret>`.
  /// The secret travels only inside the QR: never log or send it.
  final Uri qrUri;

  /// When the QR stops being answerable (UTC), on this library's clock.
  final DateTime expiresAt;

  /// A copy of this [QrSignIn] with the given fields replaced.
  QrSignIn copyWith({Uri? qrUri, DateTime? expiresAt}) => QrSignIn(
    qrUri: qrUri ?? this.qrUri,
    expiresAt: expiresAt ?? this.expiresAt,
  );

  /// The JSON form of this [QrSignIn], read back by [QrSignIn.fromJson].
  Map<String, Object?> toJson() => <String, Object?>{
    'qr_uri': qrUri.toString(),
    'expires_at': expiresAt.toUtc().toIso8601String(),
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is QrSignIn && qrUri == other.qrUri && expiresAt == other.expiresAt;

  @override
  int get hashCode => Object.hash(QrSignIn, qrUri, expiresAt);

  @override
  String toString() => 'QrSignIn(<redacted>, expiresAt: $expiresAt)';
}
