import 'package:loginflow_auth/src/core/error/login_flow_error.dart';
import 'package:loginflow_auth/src/core/error/phone_approval_refusal.dart';
import 'package:loginflow_auth/src/core/http/login_flow_envelope.dart';
import 'package:loginflow_auth/src/core/http/login_flow_transport.dart';
import 'package:loginflow_auth/src/core/http/transport_reply.dart';
import 'package:loginflow_auth/src/core/json/json_field_reader.dart';
import 'package:loginflow_auth/src/core/protocol/device_push/phone_approval_outcome.dart';
import 'package:loginflow_auth/src/core/protocol/device_push/phone_approval_request.dart';
import 'package:result_controller/result_controller.dart';

/// The approver's half of a sign-in by phone approval
/// (`/v1/user/device-push/*`, `doc/server-contract.md` §21): the requests
/// waiting for the signed-in person, and their decision. Same `/v1/user`
/// scope, session token and envelope as the passkey account API.
///
/// Fixed account-API paths resolved from [issuer], not from discovery.
class DevicePushClient {
  const DevicePushClient({required this.transport, required this.issuer});

  final LoginFlowTransport transport;
  final Uri issuer;

  Uri get _scope => issuer.replace(path: '${issuer.path}/v1/user/device-push');

  Uri _route(String route) => _scope.replace(path: '${_scope.path}/$route');

  Uri _decision(String requestId, String decision) =>
      _route('${Uri.encodeComponent(requestId)}/$decision');

  /// `GET /v1/user/device-push/pending`: oldest first, `[]` when nothing
  /// waits.
  Future<Result<List<PhoneApprovalRequest>, LoginFlowError>> pending({
    required String bearerToken,
  }) async {
    final reply = await transport.getJson(
      _route('pending'),
      bearerToken: bearerToken,
    );
    return reply.flatMap(
      (reply) => reply.isSuccess
          ? reply.envelopeModel(
              (json) => List<PhoneApprovalRequest>.unmodifiable(
                json.objectList('requests').map(PhoneApprovalRequest.fromJson),
              ),
            )
          : Err(_error(reply)),
    );
  }

  /// `POST /v1/user/device-push/{request_id}/approve` with the chosen
  /// [number]. Needs a passkey within the last 120 s: otherwise
  /// [StepUpRequired] and nothing is decided.
  Future<Result<PhoneApprovalOutcome, LoginFlowError>> approve({
    required String bearerToken,
    required String requestId,
    required int number,
  }) async {
    final reply = await transport.postJson(
      _decision(requestId, 'approve'),
      <String, Object?>{'number': number},
      bearerToken: bearerToken,
    );
    return reply.flatMap(
      (reply) => reply.isSuccess
          ? reply.envelopeModel(PhoneApprovalOutcome.fromDecision)
          : Err(_error(reply)),
    );
  }

  /// `POST /v1/user/device-push/{request_id}/deny`. No body is read; no
  /// recent sign-in is needed.
  Future<Result<void, LoginFlowError>> deny({
    required String bearerToken,
    required String requestId,
  }) async {
    final reply = await transport.postJson(
      _decision(requestId, 'deny'),
      const <String, Object?>{},
      bearerToken: bearerToken,
    );
    return reply.flatMap(
      (reply) => reply.isSuccess ? Ok(null) : Err(_error(reply)),
    );
  }

  /// A `device_push_*` code is [PhoneApprovalRefused]; anything else (the
  /// passkey step-up, a rate limit, an access-code subject's `403`) is the
  /// account API's usual error.
  LoginFlowError _error(TransportReply reply) => reply.toAccountApiErrorOr(
    (code) => switch (PhoneApprovalRefusal.fromWireName(code)) {
      final PhoneApprovalRefusal reason => PhoneApprovalRefused(reason: reason),
      null => null,
    },
  );
}
