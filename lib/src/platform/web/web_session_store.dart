import 'dart:convert';

import 'package:loginflow_auth/src/core/error/login_flow_error.dart';
import 'package:loginflow_auth/src/core/storage/session_store.dart';
import 'package:loginflow_auth/src/core/storage/stored_session.dart';
import 'package:result_controller/result_controller.dart';
import 'package:web/web.dart' as web;

/// [SessionStore] in `localStorage`, for clients whose tokens are bound to
/// the browser's non-extractable DPoP key (`WebDpopKeyStore`): the refresh
/// token, ID token and session metadata survive a reload and are shared by
/// the app's tabs, while the private key never leaves the browser's key
/// storage. A copied refresh token is useless without that key — the server
/// refuses it without a proof the key signed (`doc/server-contract.md` §13)
/// — which is what makes persisting it acceptable at all; a client without
/// DPoP keeps `InMemorySessionStore` instead.
final class WebSessionStore implements SessionStore {
  const WebSessionStore({required this.key});

  final String key;

  @override
  Future<Result<StoredSession?, LoginFlowError>> read() async {
    final raw = web.window.localStorage.getItem(key);
    if (raw == null) {
      return Ok(null);
    }
    try {
      final json = jsonDecode(raw);
      if (json is! Map<String, Object?>) {
        return Err(const StorageFailure(description: 'Corrupt session.'));
      }
      return Ok(StoredSession.fromJson(json));
    } on FormatException catch (error) {
      return Err(StorageFailure(description: error.message));
    }
  }

  @override
  Future<Result<void, LoginFlowError>> write(StoredSession session) async {
    web.window.localStorage.setItem(key, jsonEncode(session.toJson()));
    return Ok(null);
  }

  @override
  Future<Result<void, LoginFlowError>> clear() async {
    web.window.localStorage.removeItem(key);
    return Ok(null);
  }
}
