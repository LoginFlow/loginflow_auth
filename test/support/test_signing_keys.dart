import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:loginflow_auth/src/core/crypto/base64_url_encoding.dart';
import 'package:loginflow_auth/src/core/crypto/unsigned_big_int.dart';
import 'package:pointycastle/export.dart';

/// Issuer signing keys for the fake server: one RSA-2048 key for RS256 and
/// one P-256 key for ES256, like the JWKS LoginFlow will publish
/// (`doc/decisions.md` D6, D7).
class TestSigningKeys {
  TestSigningKeys._(this._rsa, this._ec, this._random);

  factory TestSigningKeys.generate() {
    final random = FortunaRandom()
      ..seed(
        KeyParameter(
          Uint8List.fromList(
            List<int>.generate(32, (_) => Random.secure().nextInt(256)),
          ),
        ),
      );
    final rsaGenerator = RSAKeyGenerator()
      ..init(
        ParametersWithRandom(
          RSAKeyGeneratorParameters(BigInt.from(65537), 2048, 64),
          random,
        ),
      );
    final ecGenerator = ECKeyGenerator()
      ..init(
        ParametersWithRandom(
          ECKeyGeneratorParameters(ECCurve_secp256r1()),
          random,
        ),
      );
    return TestSigningKeys._(
      rsaGenerator.generateKeyPair(),
      ecGenerator.generateKeyPair(),
      random,
    );
  }

  static const String rsaKeyId = 'rsa-2026-10';
  static const String ecKeyId = 'ec-2026-10';

  final AsymmetricKeyPair<PublicKey, PrivateKey> _rsa;
  final AsymmetricKeyPair<PublicKey, PrivateKey> _ec;
  final SecureRandom _random;

  RSAPublicKey get _rsaPublic => _rsa.publicKey as RSAPublicKey;
  ECPublicKey get _ecPublic => _ec.publicKey as ECPublicKey;

  /// Only the RSA key, as before an EC key is published.
  Map<String, Object?> get rsaOnlyJwks => <String, Object?>{
    'keys': <Map<String, Object?>>[
      (jwks['keys']! as List<Object?>).first! as Map<String, Object?>,
    ],
  };

  Map<String, Object?> get jwks => <String, Object?>{
    'keys': <Map<String, Object?>>[
      <String, Object?>{
        'kty': 'RSA',
        'kid': rsaKeyId,
        'alg': 'RS256',
        'use': 'sig',
        'n': _minimal(_rsaPublic.modulus!).toBase64UrlNoPadding(),
        'e': _minimal(_rsaPublic.publicExponent!).toBase64UrlNoPadding(),
      },
      <String, Object?>{
        'kty': 'EC',
        'kid': ecKeyId,
        'alg': 'ES256',
        'use': 'sig',
        'crv': 'P-256',
        'x': _ecPublic.Q!.x!
            .toBigInteger()!
            .toUnsignedBytes(32)
            .toBase64UrlNoPadding(),
        'y': _ecPublic.Q!.y!
            .toBigInteger()!
            .toUnsignedBytes(32)
            .toBase64UrlNoPadding(),
      },
    ],
  };

  /// A compact JWS over [claims].
  String sign(
    Map<String, Object?> claims, {
    String algorithm = 'RS256',
    String? keyId,
    String? type,
    bool omitsKeyId = false,
    Map<String, Object?> extraHeader = const <String, Object?>{},
  }) {
    final signingAlgorithm = algorithm == 'ES256' ? 'ES256' : 'RS256';
    final header = <String, Object?>{
      'alg': algorithm,
      if (!omitsKeyId)
        'kid': keyId ?? (signingAlgorithm == 'ES256' ? ecKeyId : rsaKeyId),
      'typ': ?type,
      ...extraHeader,
    };
    final signingInput =
        '${utf8.encode(jsonEncode(header)).toBase64UrlNoPadding()}.'
        '${utf8.encode(jsonEncode(claims)).toBase64UrlNoPadding()}';
    final message = Uint8List.fromList(ascii.encode(signingInput));
    final signature = switch (signingAlgorithm) {
      'ES256' => _signEs256(message),
      _ => _signRs256(message),
    };
    return '$signingInput.${signature.toBase64UrlNoPadding()}';
  }

  List<int> _signRs256(Uint8List message) {
    final signer = RSASigner(SHA256Digest(), '0609608648016503040201')
      ..init(
        true,
        PrivateKeyParameter<RSAPrivateKey>(_rsa.privateKey as RSAPrivateKey),
      );
    return signer.generateSignature(message).bytes;
  }

  List<int> _signEs256(Uint8List message) {
    final signer = ECDSASigner(SHA256Digest())
      ..init(
        true,
        ParametersWithRandom(
          PrivateKeyParameter<ECPrivateKey>(_ec.privateKey as ECPrivateKey),
          _random,
        ),
      );
    final signature = signer.generateSignature(message) as ECSignature;
    return <int>[
      ...signature.r.toUnsignedBytes(32),
      ...signature.s.toUnsignedBytes(32),
    ];
  }

  static List<int> _minimal(BigInt value) =>
      value.toUnsignedBytes((value.bitLength + 7) ~/ 8);
}
