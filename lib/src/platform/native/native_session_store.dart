import 'dart:convert';

import 'package:loginflow_auth/src/core/error/login_flow_error.dart';
import 'package:loginflow_auth/src/core/storage/session_store.dart';
import 'package:loginflow_auth/src/core/storage/stored_session.dart';
import 'package:loginflow_auth/src/platform/native/native_channel.dart';
import 'package:result_controller/result_controller.dart';

/// [SessionStore] in this app's private secure storage: a Keychain item
/// (`AfterFirstUnlockThisDeviceOnly`, never synchronizable) on Apple
/// platforms, Android-Keystore AES-GCM encrypted preferences on Android
/// (`doc/decisions.md` D9).
final class NativeSessionStore implements SessionStore {
  NativeSessionStore({
    required String issuer,
    required String clientId,
    this.sharedAccessGroup,
  }) : key = 'session|$issuer|$clientId';

  final String key;

  /// The Native SSO access group, so the Apple side can refuse to store a
  /// private item in it by mistake.
  final String? sharedAccessGroup;

  @override
  Future<Result<StoredSession?, LoginFlowError>> read() async {
    final raw = await NativeChannel.invokeStorage(
      NativeChannel.privateRead,
      _arguments(),
    );
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
  Future<Result<void, LoginFlowError>> write(StoredSession session) async {
    final written = await NativeChannel.invokeStorage(
      NativeChannel.privateWrite,
      _arguments(value: jsonEncode(session.toJson())),
    );
    return written.map((_) {});
  }

  @override
  Future<Result<void, LoginFlowError>> clear() async {
    final deleted = await NativeChannel.invokeStorage(
      NativeChannel.privateDelete,
      _arguments(),
    );
    return deleted.map((_) {});
  }

  Map<String, Object?> _arguments({String? value}) => <String, Object?>{
    'key': key,
    'value': ?value,
    'sharedAccessGroup': ?sharedAccessGroup,
  };
}
