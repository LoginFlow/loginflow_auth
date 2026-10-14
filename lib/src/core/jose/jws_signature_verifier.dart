import 'dart:convert';
import 'dart:typed_data';

import 'package:loginflow_auth/src/core/crypto/base64_url_encoding.dart';
import 'package:loginflow_auth/src/core/crypto/unsigned_big_int.dart';
import 'package:loginflow_auth/src/core/jose/compact_jws.dart';
import 'package:loginflow_auth/src/core/jose/json_web_key.dart';
import 'package:pointycastle/export.dart';

/// Verifies RS256 (RFC 7518 §3.3) and ES256 (RFC 7518 §3.4) signatures.
class JwsSignatureVerifier {
  const JwsSignatureVerifier();

  /// Minimum RSA modulus size accepted (RFC 7518 §3.3: 2048 bits or larger).
  static const int minimumRsaModulusBits = 2048;

  /// DER prefix of the SHA-256 `DigestInfo` used by PKCS#1 v1.5.
  static const String _sha256DigestIdentifier = '0609608648016503040201';

  bool verify(CompactJws jws, JsonWebKey key) {
    final signature = jws.signature.tryDecodeBase64Url();
    if (signature == null || !key.canVerify(jws.header.algorithm)) {
      return false;
    }
    final message = Uint8List.fromList(ascii.encode(jws.signingInput));
    return switch (jws.header.algorithm) {
      'RS256' => _verifyRs256(message, signature, key),
      'ES256' => _verifyEs256(message, signature, key),
      _ => false,
    };
  }

  bool _verifyRs256(Uint8List message, Uint8List signature, JsonWebKey key) {
    final modulusBytes = key.modulus?.tryDecodeBase64Url();
    final exponentBytes = key.exponent?.tryDecodeBase64Url();
    if (modulusBytes == null || exponentBytes == null) {
      return false;
    }
    final modulus = modulusBytes.toUnsignedBigInt();
    if (modulus.bitLength < minimumRsaModulusBits ||
        signature.length != (modulus.bitLength + 7) ~/ 8) {
      return false;
    }
    final signer = RSASigner(SHA256Digest(), _sha256DigestIdentifier)
      ..init(
        false,
        PublicKeyParameter<RSAPublicKey>(
          RSAPublicKey(modulus, exponentBytes.toUnsignedBigInt()),
        ),
      );
    try {
      return signer.verifySignature(message, RSASignature(signature));
    } on ArgumentError {
      return false;
    }
  }

  bool _verifyEs256(Uint8List message, Uint8List signature, JsonWebKey key) {
    final xBytes = key.x?.tryDecodeBase64Url();
    final yBytes = key.y?.tryDecodeBase64Url();
    if (xBytes == null ||
        yBytes == null ||
        xBytes.length != 32 ||
        yBytes.length != 32 ||
        signature.length != 64) {
      return false;
    }
    final domain = ECCurve_secp256r1();
    final point = domain.curve.createPoint(
      xBytes.toUnsignedBigInt(),
      yBytes.toUnsignedBigInt(),
    );
    final signer = ECDSASigner(
      SHA256Digest(),
    )..init(false, PublicKeyParameter<ECPublicKey>(ECPublicKey(point, domain)));
    try {
      return signer.verifySignature(
        message,
        ECSignature(
          signature.sublist(0, 32).toUnsignedBigInt(),
          signature.sublist(32).toUnsignedBigInt(),
        ),
      );
    } on ArgumentError {
      return false;
    }
  }
}
