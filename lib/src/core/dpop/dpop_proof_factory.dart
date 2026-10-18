import 'dart:convert';

import 'package:loginflow_auth/src/core/browser/callback_uri_matching.dart';
import 'package:loginflow_auth/src/core/config/login_flow_clock.dart';
import 'package:loginflow_auth/src/core/crypto/base64_url_encoding.dart';
import 'package:loginflow_auth/src/core/crypto/secure_random_source.dart';
import 'package:loginflow_auth/src/core/crypto/sha256_hashing.dart';
import 'package:loginflow_auth/src/core/dpop/dpop_key_store.dart';
import 'package:loginflow_auth/src/core/error/login_flow_error.dart';
import 'package:loginflow_auth/src/core/jose/ec_jwk_thumbprint.dart';
import 'package:result_controller/result_controller.dart';

/// Builds a DPoP proof JWT (RFC 9449 §4.2) over the platform's non-exportable
/// key, for the token endpoint, the authorization challenge endpoint, and
/// resource requests that carry an access token.
class DpopProofFactory {
  const DpopProofFactory({
    required this.keyStore,
    this.randomSource = const PlatformSecureRandomSource(),
    this.clock = const SystemLoginFlowClock(),
  });

  final DpopKeyStore keyStore;
  final SecureRandomSource randomSource;
  final LoginFlowClock clock;

  /// `htu` drops the query and fragment (RFC 9449 §4.2); [accessToken],
  /// when given, becomes the `ath` claim (RFC 9449 §4.2, used on resource
  /// requests, never on the token endpoint's first exchange). [nonce] is the
  /// last `DPoP-Nonce` the server sent for this authorization server, when
  /// any.
  Future<Result<String, LoginFlowError>> buildProof({
    required String httpMethod,
    required Uri httpUri,
    String? nonce,
    String? accessToken,
  }) async {
    final keyResult = await keyStore.ensureKey();
    if (keyResult case Err(:final error)) {
      return Err(error);
    }
    final key = keyResult.data;
    final header = <String, Object?>{
      'typ': 'dpop+jwt',
      'alg': 'ES256',
      'jwk': key.publicJwk.toJson(),
    };
    final payload = <String, Object?>{
      'htm': httpMethod,
      'htu': httpUri.withoutResponseParameters().toString(),
      'iat': clock.now().millisecondsSinceEpoch ~/ 1000,
      'jti': randomSource.nextOpaqueToken(),
      'nonce': ?nonce,
      'ath': ?accessToken?.toAccessTokenHash(),
    };
    final signingInput =
        '${_encodeSegment(header)}.${_encodeSegment(payload)}';
    final signatureResult = await keyStore.sign(
      ascii.encode(signingInput),
      keyId: key.keyId,
    );
    if (signatureResult case Err(:final error)) {
      return Err(error);
    }
    return Ok('$signingInput.${signatureResult.data}');
  }

  /// The RFC 7638 thumbprint of the platform key every proof is signed
  /// with: the `jkt` the server binds DPoP tokens and refresh families to.
  Future<Result<String, LoginFlowError>> keyThumbprint() async {
    final keyResult = await keyStore.ensureKey();
    return keyResult.map((key) => key.publicJwk.toEcThumbprint());
  }

  String _encodeSegment(Map<String, Object?> json) =>
      utf8.encode(jsonEncode(json)).toBase64UrlNoPadding();
}

/// RFC 9449 §4.2: `ath` is `BASE64URL(SHA256(ASCII(access_token)))`.
extension AccessTokenHash on String {
  String toAccessTokenHash() => ascii.encode(this).toSha256().toBase64UrlNoPadding();
}
