import 'package:loginflow_auth/src/core/error/login_flow_error.dart';
import 'package:loginflow_auth/src/core/storage/stored_session.dart';
import 'package:result_controller/result_controller.dart';

/// Per-app private storage for the [StoredSession] (refresh token, ID token,
/// `auth_session`). Implementations: Keychain / Keystore-encrypted
/// preferences on device, the Secret Service on Linux, `localStorage` on the
/// web for a DPoP-bound session and memory otherwise.
abstract interface class SessionStore {
  /// The stored session, or `null` when there is none.
  Future<Result<StoredSession?, LoginFlowError>> read();

  /// Replaces the stored session with [session].
  Future<Result<void, LoginFlowError>> write(StoredSession session);

  /// Deletes the stored session.
  Future<Result<void, LoginFlowError>> clear();
}
