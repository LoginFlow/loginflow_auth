import 'dart:convert';

import 'package:loginflow_auth/src/core/crypto/base64_url_encoding.dart';
import 'package:loginflow_auth/src/core/crypto/sha256_hashing.dart';
import 'package:loginflow_auth/src/core/jose/json_web_key.dart';

/// RFC 7638 JWK thumbprint of an EC public key.
extension EcJwkThumbprint on JsonWebKey {
  /// `BASE64URL(SHA-256)` over the required members in lexicographic order
  /// without whitespace (RFC 7638 §3.2): the `jkt` a DPoP-bound token
  /// carries in `cnf` (RFC 9449 §6.1).
  String toEcThumbprint() => utf8
      .encode(
        jsonEncode(<String, String?>{
          'crv': curve,
          'kty': keyType,
          'x': x,
          'y': y,
        }),
      )
      .toSha256()
      .toBase64UrlNoPadding();
}
