import 'dart:convert';

import 'package:loginflow_auth/src/core/error/login_flow_error.dart';
import 'package:loginflow_auth/src/core/storage/session_store.dart';
import 'package:loginflow_auth/src/core/storage/stored_session.dart';
import 'package:loginflow_auth/src/platform/linux/linux_keyring.dart';
import 'package:result_controller/result_controller.dart';

/// [SessionStore] in the user's Secret Service keyring ([LinuxKeyring]).
final class LinuxSessionStore implements SessionStore {
  LinuxSessionStore({
    required String issuer,
    required String clientId,
    this.keyring = const LinuxKeyring(),
  }) : key = 'session|$issuer|$clientId';

  final String key;
  final LinuxKeyring keyring;

  @override
  Future<Result<StoredSession?, LoginFlowError>> read() async {
    final raw = await keyring.read(key);
    return raw.flatMap((value) {
      if (value == null) {
        return Ok(null);
      }
      try {
        final json = jsonDecode(value);
        if (json is! Map<String, Object?>) {
          return Err(const StorageFailure(description: 'Corrupt session.'));
        }
        return Ok(StoredSession.fromJson(json));
      } on FormatException catch (error) {
        return Err(StorageFailure(description: error.message));
      }
    });
  }

  @override
  Future<Result<void, LoginFlowError>> write(StoredSession session) =>
      keyring.write(key, jsonEncode(session.toJson()));

  @override
  Future<Result<void, LoginFlowError>> clear() => keyring.delete(key);
}
