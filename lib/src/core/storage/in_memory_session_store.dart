import 'package:loginflow_auth/src/core/error/login_flow_error.dart';
import 'package:loginflow_auth/src/core/storage/session_store.dart';
import 'package:loginflow_auth/src/core/storage/stored_session.dart';
import 'package:result_controller/result_controller.dart';

/// [SessionStore] that keeps the session in memory only.
///
/// The default on Flutter web: nothing reaches `localStorage`,
/// `sessionStorage` or IndexedDB, so a reload loses the session and the app
/// restores it with a top-level redirect (`prompt=none`) instead
/// (draft-ietf-oauth-browser-based-apps §6.3, `doc/decisions.md` D10).
final class InMemorySessionStore implements SessionStore {
  StoredSession? _session;

  @override
  Future<Result<StoredSession?, LoginFlowError>> read() async => Ok(_session);

  @override
  Future<Result<void, LoginFlowError>> write(StoredSession session) async {
    _session = session;
    return Ok(null);
  }

  @override
  Future<Result<void, LoginFlowError>> clear() async {
    _session = null;
    return Ok(null);
  }
}
