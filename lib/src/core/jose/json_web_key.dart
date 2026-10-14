import 'package:loginflow_auth/src/core/json/json_field_reader.dart';

/// A public signing key from the issuer's JWKS (RFC 7517 §4, RFC 7518 §6).
///
/// Only the members needed to verify RS256 (`n`, `e`) and ES256 (`crv`, `x`,
/// `y`) are kept; private members are never read.
class JsonWebKey {
  const JsonWebKey({
    required this.keyType,
    this.keyId,
    this.algorithm,
    this.use,
    this.modulus,
    this.exponent,
    this.curve,
    this.x,
    this.y,
  });

  factory JsonWebKey.fromJson(Map<String, Object?> json) => JsonWebKey(
    keyType: json.requireString('kty'),
    keyId: json.optionalString('kid'),
    algorithm: json.optionalString('alg'),
    use: json.optionalString('use'),
    modulus: json.optionalString('n'),
    exponent: json.optionalString('e'),
    curve: json.optionalString('crv'),
    x: json.optionalString('x'),
    y: json.optionalString('y'),
  );

  /// `kty`: `RSA` or `EC`.
  final String keyType;

  /// `kid`.
  final String? keyId;

  /// `alg`; when present the key may only be used with that algorithm
  /// (RFC 8725 §3.1).
  final String? algorithm;

  /// `use`; when present it must be `sig`.
  final String? use;

  /// RSA `n`, base64url.
  final String? modulus;

  /// RSA `e`, base64url.
  final String? exponent;

  /// EC `crv`.
  final String? curve;

  /// EC `x`, base64url.
  final String? x;

  /// EC `y`, base64url.
  final String? y;

  /// Whether this key may verify a token whose header says [jwsAlgorithm].
  bool canVerify(String jwsAlgorithm) {
    if (use != null && use != 'sig') {
      return false;
    }
    if (algorithm != null && algorithm != jwsAlgorithm) {
      return false;
    }
    return switch (jwsAlgorithm) {
      'RS256' => keyType == 'RSA' && modulus != null && exponent != null,
      'ES256' => keyType == 'EC' && curve == 'P-256' && x != null && y != null,
      _ => false,
    };
  }

  JsonWebKey copyWith({
    String? keyType,
    String? keyId,
    String? algorithm,
    String? use,
    String? modulus,
    String? exponent,
    String? curve,
    String? x,
    String? y,
  }) => JsonWebKey(
    keyType: keyType ?? this.keyType,
    keyId: keyId ?? this.keyId,
    algorithm: algorithm ?? this.algorithm,
    use: use ?? this.use,
    modulus: modulus ?? this.modulus,
    exponent: exponent ?? this.exponent,
    curve: curve ?? this.curve,
    x: x ?? this.x,
    y: y ?? this.y,
  );

  Map<String, Object?> toJson() => <String, Object?>{
    'kty': keyType,
    'kid': ?keyId,
    'alg': ?algorithm,
    'use': ?use,
    'n': ?modulus,
    'e': ?exponent,
    'crv': ?curve,
    'x': ?x,
    'y': ?y,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is JsonWebKey &&
          keyType == other.keyType &&
          keyId == other.keyId &&
          algorithm == other.algorithm &&
          use == other.use &&
          modulus == other.modulus &&
          exponent == other.exponent &&
          curve == other.curve &&
          x == other.x &&
          y == other.y;

  @override
  int get hashCode => Object.hash(
    keyType,
    keyId,
    algorithm,
    use,
    modulus,
    exponent,
    curve,
    x,
    y,
  );
}
