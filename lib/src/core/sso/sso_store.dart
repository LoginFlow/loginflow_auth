import 'package:loginflow_auth/src/core/error/login_flow_error.dart';
import 'package:loginflow_auth/src/core/sso/sso_entry.dart';
import 'package:result_controller/result_controller.dart';

/// Storage shared by the apps of one publisher on one device: a Keychain
/// access group on Apple platforms, signature-protected ContentProviders on
/// Android (`doc/decisions.md` D12).
abstract interface class SsoStore {
  Future<Result<SsoEntry?, LoginFlowError>> read(String issuer);

  Future<Result<void, LoginFlowError>> write(SsoEntry entry);

  /// Removes the entry from every copy this app can reach.
  Future<Result<void, LoginFlowError>> delete(String issuer);
}
