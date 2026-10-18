import 'dart:typed_data';

import 'package:loginflow_auth/src/core/crypto/base64_url_encoding.dart';
import 'package:loginflow_auth/src/core/crypto/unsigned_big_int.dart';
import 'package:loginflow_auth/src/core/dpop/dpop_key_handle.dart';
import 'package:loginflow_auth/src/core/dpop/dpop_key_store.dart';
import 'package:loginflow_auth/src/core/error/login_flow_error.dart';
import 'package:loginflow_auth/src/core/jose/json_web_key.dart';
import 'package:pointycastle/export.dart';
import 'package:result_controller/result_controller.dart';

/// [DpopKeyStore] for tests: an in-memory P-256 key via pointycastle. Real
/// apps never hold the private key in Dart (`NativeDpopKeyStore`,
/// `WebDpopKeyStore`); a test has no secure hardware to hold it in instead.
///
/// The same [seed] always yields the same key, so two instances with one
/// seed model the key surviving a reload; another seed models it being gone.
class TestDpopKeyStore implements DpopKeyStore {
  TestDpopKeyStore({int seed = 1}) : _keyId = 'test-dpop-key' {
    _random = FortunaRandom()
      ..seed(
        KeyParameter(
          Uint8List.fromList(List<int>.generate(32, (index) => index + seed)),
        ),
      );
    final generator = ECKeyGenerator()
      ..init(ParametersWithRandom(ECKeyGeneratorParameters(ECCurve_secp256r1()), _random));
    final pair = generator.generateKeyPair();
    _privateKey = pair.privateKey;
    final publicKey = pair.publicKey;
    const fieldSize = 32;
    _publicJwk = JsonWebKey(
      keyType: 'EC',
      curve: 'P-256',
      x: publicKey.Q!.x!.toBigInteger()!.toUnsignedBytes(fieldSize).toBase64UrlNoPadding(),
      y: publicKey.Q!.y!.toBigInteger()!.toUnsignedBytes(fieldSize).toBase64UrlNoPadding(),
    );
  }

  final String _keyId;
  late final ECPrivateKey _privateKey;
  late final JsonWebKey _publicJwk;
  late final FortunaRandom _random;

  @override
  Future<Result<DpopKeyHandle, LoginFlowError>> ensureKey() async =>
      Ok(DpopKeyHandle(keyId: _keyId, publicJwk: _publicJwk));

  @override
  Future<Result<String, LoginFlowError>> sign(
    List<int> signingInput, {
    required String keyId,
  }) async {
    final signer = ECDSASigner(SHA256Digest())
      ..init(
        true,
        ParametersWithRandom(
          PrivateKeyParameter<ECPrivateKey>(_privateKey),
          _random,
        ),
      );
    final signature =
        signer.generateSignature(Uint8List.fromList(signingInput)) as ECSignature;
    final bytes = <int>[
      ...signature.r.toUnsignedBytes(32),
      ...signature.s.toUnsignedBytes(32),
    ];
    return Ok(bytes.toBase64UrlNoPadding());
  }
}
