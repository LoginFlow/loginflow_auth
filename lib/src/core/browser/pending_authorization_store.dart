import 'package:loginflow_auth/src/core/browser/pending_authorization.dart';
import 'package:loginflow_auth/src/core/error/login_flow_error.dart';
import 'package:result_controller/result_controller.dart';

/// Holds the single [PendingAuthorization] of a browser round-trip.
abstract interface class PendingAuthorizationStore {
  Future<Result<PendingAuthorization?, LoginFlowError>> read();

  Future<Result<void, LoginFlowError>> write(PendingAuthorization pending);

  Future<Result<void, LoginFlowError>> clear();
}
