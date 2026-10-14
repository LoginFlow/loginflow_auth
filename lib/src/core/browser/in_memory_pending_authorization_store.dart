import 'package:loginflow_auth/src/core/browser/pending_authorization.dart';
import 'package:loginflow_auth/src/core/browser/pending_authorization_store.dart';
import 'package:loginflow_auth/src/core/error/login_flow_error.dart';
import 'package:result_controller/result_controller.dart';

/// [PendingAuthorizationStore] in memory: enough on iOS, Android and macOS,
/// where the browser session returns its callback to the same process.
final class InMemoryPendingAuthorizationStore
    implements PendingAuthorizationStore {
  PendingAuthorization? _pending;

  @override
  Future<Result<PendingAuthorization?, LoginFlowError>> read() async =>
      Ok(_pending);

  @override
  Future<Result<void, LoginFlowError>> write(
    PendingAuthorization pending,
  ) async {
    _pending = pending;
    return Ok(null);
  }

  @override
  Future<Result<void, LoginFlowError>> clear() async {
    _pending = null;
    return Ok(null);
  }
}
