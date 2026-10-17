import 'package:loginflow_auth/src/core/jose/json_web_key.dart';
import 'package:loginflow_auth/src/core/json/json_field_reader.dart';

/// A non-exportable DPoP signing key the platform holds (Secure Enclave,
/// Android Keystore with StrongBox when available, or a non-extractable
/// WebCrypto key). Only the public half and an opaque [keyId] the platform
/// uses to find the private key again ever reach Dart.
class DpopKeyHandle {
  const DpopKeyHandle({required this.keyId, required this.publicJwk});

  factory DpopKeyHandle.fromJson(Map<String, Object?> json) => DpopKeyHandle(
    keyId: json.requireString('key_id'),
    publicJwk: JsonWebKey.fromJson(
      json.optionalObject('public_jwk') ?? const <String, Object?>{},
    ),
  );

  /// Identifies the key to the platform store; never sent to the server.
  final String keyId;

  /// The public EC P-256 key (RFC 9449 §4.2's `jwk` header member).
  final JsonWebKey publicJwk;

  DpopKeyHandle copyWith({String? keyId, JsonWebKey? publicJwk}) =>
      DpopKeyHandle(
        keyId: keyId ?? this.keyId,
        publicJwk: publicJwk ?? this.publicJwk,
      );

  Map<String, Object?> toJson() => <String, Object?>{
    'key_id': keyId,
    'public_jwk': publicJwk.toJson(),
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DpopKeyHandle &&
          keyId == other.keyId &&
          publicJwk == other.publicJwk;

  @override
  int get hashCode => Object.hash(keyId, publicJwk);
}
