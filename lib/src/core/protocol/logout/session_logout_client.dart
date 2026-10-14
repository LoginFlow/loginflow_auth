import 'package:loginflow_auth/src/core/error/login_flow_error.dart';
import 'package:loginflow_auth/src/core/http/login_flow_transport.dart';
import 'package:loginflow_auth/src/core/http/oauth_error_body.dart';
import 'package:result_controller/result_controller.dart';

/// LoginFlow's server-side session logout endpoints (device session and
/// "everywhere"). They are a LoginFlow extension: OpenID Connect Native SSO
/// defines no logout endpoint, see `doc/server-contract.md`.
class SessionLogoutClient {
  const SessionLogoutClient({required this.transport, required this.clientId});

  final LoginFlowTransport transport;
  final String clientId;

  /// Authenticated with the user's current access token (RFC 6750 §2.1); the
  /// server derives user, company and `sid` from it.
  Future<Result<void, LoginFlowError>> endSessions(
    Uri endpoint,
    String accessToken,
  ) async {
    final reply = await transport.postForm(endpoint, <String, String>{
      'client_id': clientId,
    }, bearerToken: accessToken);
    return reply.flatMap(
      (reply) => reply.isSuccess ? Ok(null) : Err(reply.toLoginFlowError()),
    );
  }
}
