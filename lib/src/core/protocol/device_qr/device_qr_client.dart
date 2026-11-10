import 'package:loginflow_auth/src/core/error/login_flow_error.dart';
import 'package:loginflow_auth/src/core/error/sign_in_qr_refusal.dart';
import 'package:loginflow_auth/src/core/http/login_flow_envelope.dart';
import 'package:loginflow_auth/src/core/http/login_flow_transport.dart';
import 'package:loginflow_auth/src/core/http/transport_reply.dart';
import 'package:loginflow_auth/src/core/json/json_field_reader.dart';
import 'package:loginflow_auth/src/core/protocol/device_qr/sign_in_qr.dart';
import 'package:loginflow_auth/src/core/protocol/device_qr/sign_in_qr_details.dart';
import 'package:result_controller/result_controller.dart';

/// The approver's half of a sign-in by QR (`/v1/user/device-qr/*`,
/// `doc/server-contract.md` §21): who asks, and the decision. Same
/// `/v1/user` scope, session token and envelope as the passkey account API.
/// Every route is a `POST` whose JSON body carries the QR's secret, never
/// a URL.
///
/// Fixed account-API paths resolved from [issuer], not from discovery.
class DeviceQrClient {
  const DeviceQrClient({required this.transport, required this.issuer});

  final LoginFlowTransport transport;
  final Uri issuer;

  Uri _route(SignInQr qr, String route) => issuer.replace(
    path:
        '${issuer.path}/v1/user/device-qr/'
        '${Uri.encodeComponent(qr.requestId)}/$route',
  );

  /// `POST /v1/user/device-qr/{request_id}/details`.
  Future<Result<SignInQrDetails, LoginFlowError>> details({
    required String bearerToken,
    required SignInQr qr,
  }) async {
    final reply = await _post(bearerToken, qr, 'details');
    return reply.flatMap(
      (reply) => reply.isSuccess
          ? reply.envelopeModel(SignInQrDetails.fromJson)
          : Err(_error(reply)),
    );
  }

  /// `POST /v1/user/device-qr/{request_id}/approve`. Needs a passkey within
  /// the last 120 s: otherwise [StepUpRequired] and nothing is decided.
  Future<Result<void, LoginFlowError>> approve({
    required String bearerToken,
    required SignInQr qr,
  }) => _decide(bearerToken, qr, 'approve', 'approved');

  /// `POST /v1/user/device-qr/{request_id}/deny`. No recent sign-in needed.
  Future<Result<void, LoginFlowError>> deny({
    required String bearerToken,
    required SignInQr qr,
  }) => _decide(bearerToken, qr, 'deny', 'denied');

  Future<Result<void, LoginFlowError>> _decide(
    String bearerToken,
    SignInQr qr,
    String route,
    String expectedStatus,
  ) async {
    final reply = await _post(bearerToken, qr, route);
    return reply.flatMap(
      (reply) => reply.isSuccess
          ? reply
                .envelopeModel((json) => json.requireString('status'))
                .flatMap(
                  (status) => status == expectedStatus
                      ? Ok(null)
                      : Err(
                          ServerResponseInvalid(
                            statusCode: reply.statusCode,
                            description:
                                'Unexpected QR decision "$status" for $route.',
                          ),
                        ),
                )
          : Err(_error(reply)),
    );
  }

  Future<Result<TransportReply, LoginFlowError>> _post(
    String bearerToken,
    SignInQr qr,
    String route,
  ) => transport.postJson(_route(qr, route), <String, Object?>{
    'secret': qr.secret,
  }, bearerToken: bearerToken);

  /// A `device_qr_*` code is [SignInQrRefused]; anything else (the passkey
  /// step-up, a rate limit, an access-code subject's `403`) is the account
  /// API's usual error.
  LoginFlowError _error(TransportReply reply) => reply.toAccountApiErrorOr(
    (code) => switch (SignInQrRefusal.fromWireName(code)) {
      final SignInQrRefusal reason => SignInQrRefused(reason: reason),
      null => null,
    },
  );
}
