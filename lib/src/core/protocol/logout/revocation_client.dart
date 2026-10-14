import 'package:loginflow_auth/src/core/error/login_flow_error.dart';
import 'package:loginflow_auth/src/core/http/login_flow_transport.dart';
import 'package:loginflow_auth/src/core/http/oauth_error_body.dart';
import 'package:result_controller/result_controller.dart';

/// Token revocation (RFC 7009).
class RevocationClient {
  const RevocationClient({required this.transport, required this.clientId});

  final LoginFlowTransport transport;
  final String clientId;

  /// Revokes a refresh token; the server also invalidates the access tokens
  /// of the same grant (RFC 7009 §2). An unknown token still answers 200
  /// (§2.2), so success does not prove the token was live.
  Future<Result<void, LoginFlowError>> revokeRefreshToken(
    Uri revocationEndpoint,
    String refreshToken,
  ) async {
    final reply = await transport.postForm(revocationEndpoint, <String, String>{
      'token': refreshToken,
      'token_type_hint': 'refresh_token',
      'client_id': clientId,
    });
    return reply.flatMap(
      (reply) => reply.isSuccess ? Ok(null) : Err(reply.toLoginFlowError()),
    );
  }
}
