import 'package:loginflow_auth/src/core/error/login_flow_error.dart';
import 'package:loginflow_auth/src/core/storage/stored_session.dart';
import 'package:result_controller/result_controller.dart';

/// Per-app private storage for the [StoredSession] (refresh token, ID token,
/// `auth_session`). Implementations: Keychain / Keystore-encrypted
/// preferences on device, memory on the web.
abstract interface class SessionStore {
  Future<Result<StoredSession?, LoginFlowError>> read();

  Future<Result<void, LoginFlowError>> write(StoredSession session);

  Future<Result<void, LoginFlowError>> clear();
}
