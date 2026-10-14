import 'dart:async';

import 'package:loginflow_auth/loginflow_auth_core.dart';

/// A [SessionStore] whose next write waits for [gate], to land a sign-out
/// between "tokens accepted" and "tokens persisted".
class GatedWriteSessionStore implements SessionStore {
  final InMemorySessionStore _inner = InMemorySessionStore();
  Completer<void>? gate;
  bool isWriteHeld = false;

  @override
  Future<Result<StoredSession?, LoginFlowError>> read() => _inner.read();

  @override
  Future<Result<void, LoginFlowError>> write(StoredSession session) async {
    final held = gate;
    if (held != null) {
      gate = null;
      isWriteHeld = true;
      await held.future;
      isWriteHeld = false;
    }
    return _inner.write(session);
  }

  @override
  Future<Result<void, LoginFlowError>> clear() => _inner.clear();
}
