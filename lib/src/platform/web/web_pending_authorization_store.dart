import 'dart:convert';

import 'package:loginflow_auth/src/core/browser/pending_authorization.dart';
import 'package:loginflow_auth/src/core/browser/pending_authorization_store.dart';
import 'package:loginflow_auth/src/core/error/login_flow_error.dart';
import 'package:result_controller/result_controller.dart';
import 'package:web/web.dart' as web;

/// Keeps the PKCE verifier, `state` and `nonce` across the full-page
/// redirect in `sessionStorage`: tab-scoped, cleared when the tab closes and
/// deleted as soon as the callback is consumed. Tokens never go here.
final class WebPendingAuthorizationStore implements PendingAuthorizationStore {
  const WebPendingAuthorizationStore({required this.key});

  final String key;

  @override
  Future<Result<PendingAuthorization?, LoginFlowError>> read() async {
    final raw = web.window.sessionStorage.getItem(key);
    if (raw == null) {
      return Ok(null);
    }
    try {
      final json = jsonDecode(raw);
      if (json is! Map<String, Object?>) {
        return Err(
          const StorageFailure(description: 'Corrupt pending request.'),
        );
      }
      return Ok(PendingAuthorization.fromJson(json));
    } on FormatException catch (error) {
      return Err(StorageFailure(description: error.message));
    }
  }

  @override
  Future<Result<void, LoginFlowError>> write(
    PendingAuthorization pending,
  ) async {
    web.window.sessionStorage.setItem(key, jsonEncode(pending.toJson()));
    return Ok(null);
  }

  @override
  Future<Result<void, LoginFlowError>> clear() async {
    web.window.sessionStorage.removeItem(key);
    return Ok(null);
  }
}
