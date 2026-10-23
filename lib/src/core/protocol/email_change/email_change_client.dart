import 'package:loginflow_auth/src/core/error/login_flow_error.dart';
import 'package:loginflow_auth/src/core/http/login_flow_envelope.dart';
import 'package:loginflow_auth/src/core/http/login_flow_transport.dart';
import 'package:loginflow_auth/src/core/http/transport_reply.dart';
import 'package:loginflow_auth/src/core/protocol/email_change/email_change_confirmed.dart';
import 'package:loginflow_auth/src/core/protocol/email_change/email_change_started.dart';
import 'package:result_controller/result_controller.dart';

/// LoginFlow's self-service email change (`/v1/app/email-change*`,
/// `doc/server-contract.md` §19): the signed-in person changes their OWN
/// email. Every call carries the person's own LoginFlow token (`aud` = the
/// issuer), DPoP-bound, like the members API.
///
/// Fixed account-API paths resolved from [issuer], not from discovery.
class EmailChangeClient {
  const EmailChangeClient({required this.transport, required this.issuer});

  final LoginFlowTransport transport;
  final Uri issuer;

  Uri get _startUri =>
      issuer.replace(path: '${issuer.path}/v1/app/email-change');

  Uri get _confirmUri => _startUri.replace(path: '${_startUri.path}/confirm');

  /// `POST /v1/app/email-change` (`202`).
  Future<Result<EmailChangeStarted, LoginFlowError>> start({
    required String bearerToken,
    required String newEmail,
  }) async {
    final reply = await transport.postJson(_startUri, <String, Object?>{
      'new_email': newEmail,
    }, bearerToken: bearerToken);
    return reply.flatMap(
      (reply) => reply.isSuccess
          ? reply.envelopeModel(EmailChangeStarted.fromJson)
          : Err(_startError(reply)),
    );
  }

  /// `POST /v1/app/email-change/confirm` (`200`).
  Future<Result<EmailChangeConfirmed, LoginFlowError>> confirm({
    required String bearerToken,
    required String code,
    String? currentCode,
  }) async {
    final reply = await transport.postJson(_confirmUri, <String, Object?>{
      'code': code,
      'current_code': ?currentCode,
    }, bearerToken: bearerToken);
    return reply.flatMap(
      (reply) => reply.isSuccess
          ? reply.envelopeModel(EmailChangeConfirmed.fromJson)
          : Err(_confirmError(reply)),
    );
  }

  /// A `422` is the address; anything else (step-up, rate limit) is the
  /// account API's usual error.
  LoginFlowError _startError(TransportReply reply) => reply.statusCode == 422
      ? const InvalidEmailAddress()
      : reply.toAccountApiError();

  /// `401 INVALID_CODE` and a malformed code (`422`) are the one generic
  /// refusal; a `401` without that code (an ended session) is not.
  LoginFlowError _confirmError(TransportReply reply) {
    final isInvalidCode =
        reply.statusCode == 422 ||
        (reply.statusCode == 401 && _errorCode(reply) == _invalidCode);
    return isInvalidCode
        ? const InvalidEmailChangeCode()
        : reply.toAccountApiError();
  }

  String? _errorCode(TransportReply reply) => reply.jsonObject().when(
    ok: (json) => switch (json['error']) {
      {'code': final String code} => code,
      _ => null,
    },
    err: (_) => null,
  );

  static const String _invalidCode = 'INVALID_CODE';
}
