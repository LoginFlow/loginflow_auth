import 'package:loginflow_auth/loginflow_auth_core.dart';

/// A [SessionStore] whose writes start failing on demand, like a Keychain
/// or Keystore that becomes unavailable mid-session.
class FailingWriteSessionStore implements SessionStore {
  final InMemorySessionStore _inner = InMemorySessionStore();
  bool failsWrites = false;

  @override
  Future<Result<StoredSession?, LoginFlowError>> read() => _inner.read();

  @override
  Future<Result<void, LoginFlowError>> write(StoredSession session) async =>
      failsWrites
      ? Err(const StorageFailure(description: 'disk unavailable'))
      : _inner.write(session);

  @override
  Future<Result<void, LoginFlowError>> clear() => _inner.clear();
}
