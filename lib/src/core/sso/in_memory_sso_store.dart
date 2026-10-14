import 'package:loginflow_auth/src/core/error/login_flow_error.dart';
import 'package:loginflow_auth/src/core/sso/sso_entry.dart';
import 'package:loginflow_auth/src/core/sso/sso_store.dart';
import 'package:result_controller/result_controller.dart';

/// [SsoStore] in memory. Sharing one instance between two `LoginFlowAuth`
/// objects simulates two apps of the same publisher (tests, examples).
final class InMemorySsoStore implements SsoStore {
  final Map<String, SsoEntry> _entries = <String, SsoEntry>{};

  @override
  Future<Result<SsoEntry?, LoginFlowError>> read(String issuer) async =>
      Ok(_entries[issuer]);

  @override
  Future<Result<void, LoginFlowError>> write(SsoEntry entry) async {
    _entries[entry.issuer] = entry;
    return Ok(null);
  }

  @override
  Future<Result<void, LoginFlowError>> delete(String issuer) async {
    _entries.remove(issuer);
    return Ok(null);
  }
}
