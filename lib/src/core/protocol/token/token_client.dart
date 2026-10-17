import 'package:loginflow_auth/src/core/error/login_flow_error.dart';
import 'package:loginflow_auth/src/core/http/login_flow_transport.dart';
import 'package:loginflow_auth/src/core/http/oauth_error_body.dart';
import 'package:loginflow_auth/src/core/http/transport_reply.dart';
import 'package:loginflow_auth/src/core/protocol/challenge/challenge_response.dart';
import 'package:loginflow_auth/src/core/protocol/token/token_grant.dart';
import 'package:loginflow_auth/src/core/protocol/token/token_response.dart';
import 'package:result_controller/result_controller.dart';

/// Talks to the token endpoint.
class TokenClient {
  const TokenClient({required this.transport, required this.clientId});

  final LoginFlowTransport transport;
  final String clientId;

  Future<Result<TokenResponse, LoginFlowError>> request(
    Uri tokenEndpoint,
    TokenGrant grant,
  ) async {
    final reply = await transport.postForm(
      tokenEndpoint,
      grant.toFormFields(clientId: clientId),
    );
    return reply.flatMap(_toResponse);
  }

  Result<TokenResponse, LoginFlowError> _toResponse(TransportReply reply) {
    if (reply.isSuccess) {
      return reply.jsonObject().flatMap((json) {
        try {
          final response = TokenResponse.fromJson(json);
          return response.isBearer || response.isDpop
              ? Ok(response)
              : Err(
                  ServerResponseInvalid(
                    statusCode: reply.statusCode,
                    description: 'Unsupported token_type ${response.tokenType}',
                  ),
                );
        } on FormatException catch (error) {
          return Err(
            ServerResponseInvalid(
              statusCode: reply.statusCode,
              description: error.message,
            ),
          );
        }
      });
    }
    if (reply.statusCode == 403) {
      final challenge = _stepRequired(reply);
      if (challenge != null) {
        return Err(InsufficientAuthorization(challenge: challenge));
      }
    }
    return Err(reply.toLoginFlowError());
  }

  /// draft-ietf-oauth-first-party-apps-04 §6.2: any token request may answer
  /// `insufficient_authorization` with an `auth_session`.
  ChallengeStepRequired? _stepRequired(TransportReply reply) =>
      reply.jsonObject().when(
        ok: (json) {
          if (json['error'] != ChallengeStepRequired.errorCode) {
            return null;
          }
          try {
            return ChallengeStepRequired.fromJson(json);
          } on FormatException {
            return null;
          }
        },
        err: (_) => null,
      );
}
