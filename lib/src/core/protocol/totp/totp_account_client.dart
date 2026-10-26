import 'package:loginflow_auth/src/core/error/login_flow_error.dart';
import 'package:loginflow_auth/src/core/http/login_flow_envelope.dart';
import 'package:loginflow_auth/src/core/http/login_flow_transport.dart';
import 'package:loginflow_auth/src/core/http/transport_reply.dart';
import 'package:loginflow_auth/src/core/json/json_field_reader.dart';
import 'package:loginflow_auth/src/core/protocol/totp/totp_enrollment.dart';
import 'package:loginflow_auth/src/core/protocol/totp/totp_status.dart';
import 'package:result_controller/result_controller.dart';

/// LoginFlow's authenticated TOTP account API (`/v1/user/totp/*`,
/// `doc/server-contract.md` §20): the signed-in person's authenticator app
/// and recovery codes. Same `/v1/user` scope and session token as the
/// passkey account API.
///
/// Fixed account-API paths resolved from [issuer], not from discovery.
class TotpAccountClient {
  const TotpAccountClient({required this.transport, required this.issuer});

  final LoginFlowTransport transport;
  final Uri issuer;

  Uri get _scope => issuer.replace(path: '${issuer.path}/v1/user/totp');

  Uri _route(String route) => _scope.replace(path: '${_scope.path}/$route');

  /// `GET /v1/user/totp/status`.
  Future<Result<TotpStatus, LoginFlowError>> status({
    required String bearerToken,
  }) async {
    final reply = await transport.getJson(
      _route('status'),
      bearerToken: bearerToken,
    );
    return reply.flatMap(
      (reply) => reply.isSuccess
          ? reply.envelopeModel(TotpStatus.fromJson)
          : Err(_error(reply)),
    );
  }

  /// `POST /v1/user/totp/setup`. Without [issuer] the server names the
  /// entry after the application, then the company.
  Future<Result<TotpEnrollment, LoginFlowError>> setup({
    required String bearerToken,
    String? issuer,
  }) async {
    final reply = await transport.postJson(_route('setup'), <String, Object?>{
      'issuer': ?issuer,
    }, bearerToken: bearerToken);
    return reply.flatMap(
      (reply) => reply.isSuccess
          ? reply.envelopeModel(TotpEnrollment.fromJson)
          : Err(_error(reply)),
    );
  }

  /// `POST /v1/user/totp/verify-setup`: turns the pending secret on.
  Future<Result<void, LoginFlowError>> verifySetup({
    required String bearerToken,
    required String code,
  }) => _sendCode(route: 'verify-setup', bearerToken: bearerToken, code: code);

  /// `POST /v1/user/totp/disable`.
  Future<Result<void, LoginFlowError>> disable({
    required String bearerToken,
    required String code,
  }) => _sendCode(route: 'disable', bearerToken: bearerToken, code: code);

  /// `POST /v1/user/totp/recovery-codes`: a new set, every earlier code
  /// void.
  Future<Result<List<String>, LoginFlowError>> regenerateRecoveryCodes({
    required String bearerToken,
  }) async {
    final reply = await transport.postJson(
      _route('recovery-codes'),
      const <String, Object?>{},
      bearerToken: bearerToken,
    );
    return reply.flatMap(
      (reply) => reply.isSuccess
          ? reply.envelopeModel((json) => json.stringList('recovery_codes'))
          : Err(_error(reply)),
    );
  }

  Future<Result<void, LoginFlowError>> _sendCode({
    required String route,
    required String bearerToken,
    required String code,
  }) async {
    final reply = await transport.postJson(_route(route), <String, Object?>{
      'code': code,
    }, bearerToken: bearerToken);
    return reply.flatMap(
      (reply) => reply.isSuccess ? Ok(null) : Err(_error(reply)),
    );
  }

  /// `401 INVALID_CODE` is a refused code (a `401` without that code is an
  /// ended session or a step-up); a coded `403` is a principal the route
  /// cannot serve; anything else is the account API's usual error.
  LoginFlowError _error(TransportReply reply) {
    final code = reply.jsonObject().when(
      ok: (json) => json.optionalObject('error')?.optionalString('code'),
      err: (_) => null,
    );
    return switch ((reply.statusCode, code)) {
      (401, _invalidCode) => const InvalidTotpCode(),
      (403, final String code) => TotpAccountRefused(code: code),
      _ => reply.toAccountApiError(),
    };
  }

  static const String _invalidCode = 'INVALID_CODE';
}
