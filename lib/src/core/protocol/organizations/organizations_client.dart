import 'package:loginflow_auth/src/core/error/login_flow_error.dart';
import 'package:loginflow_auth/src/core/http/login_flow_transport.dart';
import 'package:loginflow_auth/src/core/http/oauth_error_body.dart';
import 'package:loginflow_auth/src/core/protocol/organizations/organization_list.dart';
import 'package:result_controller/result_controller.dart';

/// Reads the organizations the signed-in user can work in
/// (`GET {organizations_endpoint}`, `doc/server-contract.md` §17), with the
/// session's own access token (Bearer, or DPoP-bound).
class OrganizationsClient {
  const OrganizationsClient({required this.transport});

  final LoginFlowTransport transport;

  Future<Result<OrganizationList, LoginFlowError>> list(
    Uri endpoint, {
    required String bearerToken,
  }) async {
    final reply = await transport.getJson(endpoint, bearerToken: bearerToken);
    return reply.flatMap((reply) {
      if (!reply.isSuccess) {
        return Err(reply.toLoginFlowError());
      }
      return reply.jsonObject().flatMap((json) {
        try {
          return Ok(OrganizationList.fromJson(json));
        } on FormatException catch (error) {
          return Err(
            ServerResponseInvalid(
              statusCode: reply.statusCode,
              description: error.message,
            ),
          );
        }
      });
    });
  }
}
