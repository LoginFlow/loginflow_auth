import 'dart:convert';

import 'package:loginflow_auth/src/core/crypto/base64_url_encoding.dart';
import 'package:loginflow_auth/src/core/dpop/dpop_key_handle.dart';
import 'package:loginflow_auth/src/core/dpop/dpop_key_store.dart';
import 'package:loginflow_auth/src/core/error/login_flow_error.dart';
import 'package:loginflow_auth/src/platform/native/native_channel.dart';
import 'package:result_controller/result_controller.dart';

/// [DpopKeyStore] over the Apple Secure Enclave (falling back to a
/// Keychain-only key where there is none, e.g. the Simulator) or the Android
/// Keystore (StrongBox-backed when the device has one). The private key
/// never crosses the method channel: only the public JWK and signatures do.
final class NativeDpopKeyStore implements DpopKeyStore {
  NativeDpopKeyStore({required String clientId})
    : _alias = 'dpop|$clientId';

  final String _alias;

  @override
  Future<Result<DpopKeyHandle, LoginFlowError>> ensureKey() async {
    final raw = await NativeChannel.invokeStorage(
      NativeChannel.dpopEnsureKey,
      <String, Object?>{'alias': _alias},
    );
    return raw.flatMap((value) {
      if (value == null) {
        return Err(
          const StorageFailure(description: 'No DPoP key was returned.'),
        );
      }
      try {
        final json = jsonDecode(value);
        if (json is! Map<String, Object?>) {
          return Err(
            const StorageFailure(description: 'Corrupt DPoP key handle.'),
          );
        }
        return Ok(DpopKeyHandle.fromJson(json));
      } on FormatException catch (error) {
        return Err(StorageFailure(description: error.message));
      }
    });
  }

  @override
  Future<Result<String, LoginFlowError>> sign(
    List<int> signingInput, {
    required String keyId,
  }) async {
    final raw = await NativeChannel.invokeStorage(
      NativeChannel.dpopSign,
      <String, Object?>{
        'alias': _alias,
        'keyId': keyId,
        'signingInput': signingInput.toBase64UrlNoPadding(),
      },
    );
    return raw.flatMap((value) {
      if (value == null) {
        return Err(
          const StorageFailure(description: 'No DPoP signature was returned.'),
        );
      }
      return Ok(value);
    });
  }
}
