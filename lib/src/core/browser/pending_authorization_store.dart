import 'package:loginflow_auth/src/core/browser/pending_authorization.dart';
import 'package:loginflow_auth/src/core/error/login_flow_error.dart';
import 'package:result_controller/result_controller.dart';

/// Holds the single [PendingAuthorization] of a browser round-trip.
abstract interface class PendingAuthorizationStore {
  /// The pending round-trip, or `null` when there is none.
  Future<Result<PendingAuthorization?, LoginFlowError>> read();

  /// Keeps [pending] until its callback is consumed, replacing any previous one.
  Future<Result<void, LoginFlowError>> write(PendingAuthorization pending);

  /// Deletes the pending round-trip.
  Future<Result<void, LoginFlowError>> clear();
}
