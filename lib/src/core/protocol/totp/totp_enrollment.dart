import 'package:loginflow_auth/src/core/json/json_field_reader.dart';

/// The answer of `LoginFlowAuth.startTotpEnrollment`
/// (`POST /v1/user/totp/setup`, `doc/server-contract.md` §20): a new
/// secret for the person's authenticator app. It is not active until
/// `LoginFlowAuth.confirmTotpEnrollment` succeeds with a code it produced;
/// a new start replaces it.
///
/// The secret is shown once and never persisted by the library: [toJson]
/// exists for the model contract, not for storage.
class TotpEnrollment {
  /// Creates a [TotpEnrollment].
  const TotpEnrollment({
    required this.secret,
    required this.otpauthUri,
    required this.issuer,
  });

  /// Reads a [TotpEnrollment] from its JSON form ([toJson]).
  factory TotpEnrollment.fromJson(Map<String, Object?> json) => TotpEnrollment(
    secret: json.requireString('secret'),
    otpauthUri: json.requireString('otpauth_uri'),
    issuer: json.requireString('issuer'),
  );

  /// The Base32 secret, for typing it into the app by hand.
  final String secret;

  /// The `otpauth://totp/...` URI, verbatim as the server built it: the
  /// content of the QR code the app scans.
  final String otpauthUri;

  /// The name the app shows next to the entry; empty when the URI carries
  /// none (the entry is then labeled by the email alone).
  final String issuer;

  /// A copy of this [TotpEnrollment] with the given fields replaced.
  TotpEnrollment copyWith({
    String? secret,
    String? otpauthUri,
    String? issuer,
  }) => TotpEnrollment(
    secret: secret ?? this.secret,
    otpauthUri: otpauthUri ?? this.otpauthUri,
    issuer: issuer ?? this.issuer,
  );

  /// The JSON form of this [TotpEnrollment], read back by [TotpEnrollment.fromJson].
  Map<String, Object?> toJson() => <String, Object?>{
    'secret': secret,
    'otpauth_uri': otpauthUri,
    'issuer': issuer,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TotpEnrollment &&
          secret == other.secret &&
          otpauthUri == other.otpauthUri &&
          issuer == other.issuer;

  @override
  int get hashCode => Object.hash(secret, otpauthUri, issuer);

  /// Never prints the secret.
  @override
  String toString() => 'TotpEnrollment(issuer: $issuer)';
}
