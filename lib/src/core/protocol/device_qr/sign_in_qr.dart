import 'package:loginflow_auth/src/core/json/json_field_reader.dart';

/// A sign-in QR scanned by the approver's app and checked
/// (`LoginFlowAuth.parseSignInQr`, `doc/server-contract.md` §21): the
/// request id from its path and the secret from its fragment. Pass it to
/// `LoginFlowAuth.signInQrDetails`, `approveQrSignIn` or `denyQrSignIn`;
/// the secret only ever travels in their JSON body.
class SignInQr {
  /// Creates a [SignInQr].
  const SignInQr({required this.requestId, required this.secret});

  /// Reads a [SignInQr] from its JSON form ([toJson]).
  factory SignInQr.fromJson(Map<String, Object?> json) => SignInQr(
    requestId: json.requireString('request_id'),
    secret: json.requireString('secret'),
  );

  /// The QR's request id (a UUID), the path segment after `/qr/`.
  final String requestId;

  /// The QR's secret (base64url), its fragment. Never log it.
  final String secret;

  /// A copy of this [SignInQr] with the given fields replaced.
  SignInQr copyWith({String? requestId, String? secret}) => SignInQr(
    requestId: requestId ?? this.requestId,
    secret: secret ?? this.secret,
  );

  /// The JSON form of this [SignInQr], read back by [SignInQr.fromJson].
  Map<String, Object?> toJson() => <String, Object?>{
    'request_id': requestId,
    'secret': secret,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SignInQr &&
          requestId == other.requestId &&
          secret == other.secret;

  @override
  int get hashCode => Object.hash(SignInQr, requestId, secret);

  @override
  String toString() => 'SignInQr($requestId, <redacted>)';
}
