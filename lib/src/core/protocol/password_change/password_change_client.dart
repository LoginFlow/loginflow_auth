import 'package:loginflow_auth/src/core/error/login_flow_error.dart';
import 'package:loginflow_auth/src/core/http/login_flow_envelope.dart';
import 'package:loginflow_auth/src/core/http/login_flow_transport.dart';
import 'package:loginflow_auth/src/core/http/transport_reply.dart';
import 'package:loginflow_auth/src/core/json/json_field_reader.dart';
import 'package:result_controller/result_controller.dart';

/// LoginFlow's in-app password change (`POST /v1/user/change-password`):
/// the signed-in person sets or changes their own password. Same `/v1/user`
/// scope and session token as the passkey and TOTP account APIs.
///
/// Fixed account-API path resolved from [issuer], not from discovery.
class PasswordChangeClient {
  const PasswordChangeClient({required this.transport, required this.issuer});

  final LoginFlowTransport transport;
  final Uri issuer;

  Uri get _uri =>
      issuer.replace(path: '${issuer.path}/v1/user/change-password');

  /// `POST /v1/user/change-password` (`200`).
  Future<Result<void, LoginFlowError>> change({
    required String bearerToken,
    required String newPassword,
  }) async {
    final reply = await transport.postJson(_uri, <String, Object?>{
      'new_password': newPassword,
    }, bearerToken: bearerToken);
    return reply.flatMap(
      (reply) => reply.isSuccess ? Ok(null) : Err(_error(reply)),
    );
  }

  /// A `422` is the new password, with the server's reason in
  /// `error.details`; anything else (step-up, an ended session) is the
  /// account API's usual error.
  LoginFlowError _error(TransportReply reply) {
    if (reply.statusCode != 422) {
      return reply.toAccountApiError();
    }
    final reason = reply.jsonObject().when(
      ok: (json) => json.optionalObject('error')?.optionalString('details'),
      err: (_) => null,
    );
    return PasswordRejected(reason: reason ?? 'Some fields are invalid.');
  }
}
