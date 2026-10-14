import 'package:loginflow_auth/src/core/error/login_flow_error.dart';
import 'package:loginflow_auth/src/core/http/login_flow_transport.dart';
import 'package:loginflow_auth/src/core/http/oauth_error_body.dart';
import 'package:loginflow_auth/src/core/http/transport_reply.dart';
import 'package:loginflow_auth/src/core/protocol/challenge/challenge_request.dart';
import 'package:loginflow_auth/src/core/protocol/challenge/challenge_response.dart';
import 'package:result_controller/result_controller.dart';

/// Talks to the Authorization Challenge Endpoint
/// (draft-ietf-oauth-first-party-apps-04 §4, §5).
class AuthorizationChallengeClient {
  const AuthorizationChallengeClient({required this.transport});

  final LoginFlowTransport transport;

  Future<Result<ChallengeResponse, LoginFlowError>> send(
    Uri endpoint,
    ChallengeRequest request,
  ) async {
    final reply = await transport.postForm(endpoint, request.toFormFields());
    return reply.flatMap(_toResponse);
  }

  Result<ChallengeResponse, LoginFlowError> _toResponse(TransportReply reply) {
    if (reply.statusCode == 429) {
      return Err(reply.toLoginFlowError());
    }
    return reply.jsonObject().flatMap((json) {
      try {
        return switch ((reply.statusCode, json['error'])) {
          (200, _) => Ok(ChallengeCodeIssued.fromJson(json)),
          (403, ChallengeStepRequired.errorCode) => Ok(
            ChallengeStepRequired.fromJson(json),
          ),
          (403, ChallengeRedirectToWeb.errorCode) => Ok(
            ChallengeRedirectToWeb.fromJson(json),
          ),
          (400, ChallengeSessionInvalid.errorCode) => Ok(
            ChallengeSessionInvalid.fromJson(json),
          ),
          _ => Err(reply.toLoginFlowError()),
        };
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
}
