import 'dart:typed_data';

import 'package:loginflow_auth/src/core/crypto/base64_url_encoding.dart';
import 'package:loginflow_auth/src/core/crypto/secure_random_source.dart';
import 'package:loginflow_auth/src/core/crypto/unsigned_big_int.dart';
import 'package:loginflow_auth/src/core/dpop/dpop_key_handle.dart';
import 'package:loginflow_auth/src/core/dpop/dpop_key_store.dart';
import 'package:loginflow_auth/src/core/error/login_flow_error.dart';
import 'package:loginflow_auth/src/core/jose/json_web_key.dart';
import 'package:loginflow_auth/src/platform/linux/linux_keyring.dart';
import 'package:pointycastle/export.dart';
import 'package:result_controller/result_controller.dart';

/// [DpopKeyStore] for Linux desktop. Linux has no OS API that holds a
/// non-exportable signing key for an app (no Secure Enclave, Android
/// Keystore or WebCrypto equivalent), so this is a SOFTWARE ES256 key:
/// generated from the platform CSPRNG, its private scalar kept in the user's
/// Secret Service keyring ([LinuxKeyring]) and in this process's memory
/// while it signs. Tokens are still bound to it (`cnf.jkt`): a refresh token
/// is useless without the key, but both live in the same keyring, which is
/// weaker than the hardware-backed keys of the other platforms
/// (`doc/server-contract.md` §13.1).
final class LinuxDpopKeyStore implements DpopKeyStore {
  LinuxDpopKeyStore({
    required String clientId,
    this.keyring = const LinuxKeyring(),
    SecureRandomSource randomSource = const PlatformSecureRandomSource(),
  }) : _keyId = 'dpop|$clientId',
       _random = FortunaRandom()
         ..seed(KeyParameter(Uint8List.fromList(randomSource.nextBytes(32))));

  /// P-256 coordinates and scalars are 32 bytes (RFC 7518 §6.2.1.2).
  static const int _fieldSize = 32;

  final LinuxKeyring keyring;
  final String _keyId;
  final FortunaRandom _random;
  final ECDomainParameters _curve = ECCurve_secp256r1();
  Future<Result<ECPrivateKey, LoginFlowError>>? _pending;

  @override
  Future<Result<DpopKeyHandle, LoginFlowError>> ensureKey() async {
    final key = await (_pending ??= _loadOrGenerate());
    return key.map(
      (privateKey) =>
          DpopKeyHandle(keyId: _keyId, publicJwk: _publicJwkOf(privateKey)),
    );
  }

  @override
  Future<Result<String, LoginFlowError>> sign(
    List<int> signingInput, {
    required String keyId,
  }) async {
    final key = await (_pending ??= _loadOrGenerate());
    return key.map((privateKey) {
      final signer = ECDSASigner(SHA256Digest())
        ..init(
          true,
          ParametersWithRandom(
            PrivateKeyParameter<ECPrivateKey>(privateKey),
            _random,
          ),
        );
      final signature = signer.generateSignature(
        Uint8List.fromList(signingInput),
      ) as ECSignature;
      return <int>[
        ...signature.r.toUnsignedBytes(_fieldSize),
        ...signature.s.toUnsignedBytes(_fieldSize),
      ].toBase64UrlNoPadding();
    });
  }

  /// The stored key, or a new one when none (or an unreadable one) is
  /// stored. A keyring that cannot be reached is an error, not a reason for
  /// an unpersisted key: a session bound to it would not survive a restart.
  Future<Result<ECPrivateKey, LoginFlowError>> _loadOrGenerate() async {
    final stored = await keyring.read(_keyId);
    if (stored case Err(:final error)) {
      return Err(error);
    }
    final scalar = stored.data?.tryDecodeBase64Url();
    if (scalar != null && scalar.length == _fieldSize) {
      return Ok(ECPrivateKey(scalar.toUnsignedBigInt(), _curve));
    }
    return _generate();
  }

  Future<Result<ECPrivateKey, LoginFlowError>> _generate() async {
    final generator = ECKeyGenerator()
      ..init(ParametersWithRandom(ECKeyGeneratorParameters(_curve), _random));
    final privateKey = generator.generateKeyPair().privateKey;
    // A generated key always carries its scalar `d`.
    final scalar = privateKey.d!.toUnsignedBytes(_fieldSize);
    final written = await keyring.write(_keyId, scalar.toBase64UrlNoPadding());
    return written.map((_) => privateKey);
  }

  /// `Q = d·G`; never the point at infinity for a scalar in `[1, n-1]`, so
  /// the coordinates below are always present.
  JsonWebKey _publicJwkOf(ECPrivateKey privateKey) {
    final point = (_curve.G * privateKey.d)!;
    return JsonWebKey(
      keyType: 'EC',
      curve: 'P-256',
      x: point.x!
          .toBigInteger()!
          .toUnsignedBytes(_fieldSize)
          .toBase64UrlNoPadding(),
      y: point.y!
          .toBigInteger()!
          .toUnsignedBytes(_fieldSize)
          .toBase64UrlNoPadding(),
    );
  }
}
