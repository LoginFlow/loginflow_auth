import 'package:loginflow_auth/src/core/error/login_flow_error.dart';
import 'package:loginflow_auth/src/core/http/login_flow_transport.dart';
import 'package:loginflow_auth/src/core/http/oauth_error_body.dart';
import 'package:loginflow_auth/src/core/protocol/login_options/client_login_options.dart';
import 'package:result_controller/result_controller.dart';

/// Reads the login methods the server enables for this client.
class LoginOptionsClient {
  const LoginOptionsClient({required this.transport, required this.clientId});

  final LoginFlowTransport transport;
  final String clientId;

  Future<Result<ClientLoginOptions, LoginFlowError>> fetch(Uri endpoint) async {
    final uri = endpoint.replace(
      queryParameters: <String, String>{
        ...endpoint.queryParameters,
        'client_id': clientId,
      },
    );
    final reply = await transport.getJson(uri);
    return reply.flatMap((reply) {
      if (!reply.isSuccess) {
        return Err(reply.toLoginFlowError());
      }
      return reply.jsonObject().flatMap((json) {
        try {
          final options = ClientLoginOptions.fromJson(json);
          return options.clientId == clientId
              ? Ok(options)
              : Err(
                  ServerResponseInvalid(
                    statusCode: reply.statusCode,
                    description: 'Login options are for another client.',
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
    });
  }
}
