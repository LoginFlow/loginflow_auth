import 'package:loginflow_auth/src/core/error/login_flow_error.dart';
import 'package:loginflow_auth/src/core/http/transport_reply.dart';
import 'package:loginflow_auth/src/core/json/json_field_reader.dart';
import 'package:loginflow_auth/src/core/protocol/step_up/step_up_requirement.dart';
import 'package:result_controller/result_controller.dart';

/// The `data` of LoginFlow's standard API envelope
/// (`{"data": <payload>, "meta": {...}}`), used by every `/v1/user` resource
/// route (`doc/server-contract.md` §15, `response_entity.rs`'s
/// `ApiResponse::success`/`created`) — unlike the OAuth/OIDC endpoints,
/// whose body IS the payload, with no envelope.
extension LoginFlowEnvelope on TransportReply {
  /// `data` as a JSON object.
  Result<Map<String, Object?>, LoginFlowError> envelopeObject() =>
      jsonObject().flatMap(_dataObject);

  /// `data` as a JSON array of objects.
  Result<List<Map<String, Object?>>, LoginFlowError> envelopeList() =>
      jsonObject().flatMap(_dataList);

  /// `data` read as a model by [fromJson]; a [FormatException] it throws
  /// becomes [ServerResponseInvalid].
  Result<T, LoginFlowError> envelopeModel<T>(
    T Function(Map<String, Object?> json) fromJson,
  ) => envelopeObject().flatMap((json) {
    try {
      return Ok(fromJson(json));
    } on FormatException catch (error) {
      return Err(
        ServerResponseInvalid(
          statusCode: statusCode,
          description: error.message,
        ),
      );
    }
  });

  /// The error of a failed REST call. These routes use LoginFlow's general
  /// `ApiResponse` error envelope (`{"error": {"code", "message"}}`), not
  /// the OAuth error shape (`{"error", "error_description"}`) of the
  /// OAuth/OIDC endpoints.
  ///
  /// A recent-authentication gate (RFC 9470) answers a `401` whose body is
  /// the generic `UNAUTHORIZED` envelope; only the `WWW-Authenticate`
  /// challenge says it is a step-up, so that header is read first.
  LoginFlowError toAccountApiError() {
    if (statusCode == 429) {
      return RateLimited(retryAfter: retryAfter);
    }
    final challenge = wwwAuthenticate;
    final requirement = statusCode == 401 && challenge != null
        ? StepUpRequirement.fromWwwAuthenticate(challenge)
        : null;
    if (requirement != null) {
      return StepUpRequired(requirement: requirement);
    }
    return jsonObject().when(
      ok: (json) {
        final error = json.optionalObject('error');
        final description =
            error?.optionalString('message') ?? 'Request failed.';
        return ServerResponseInvalid(
          statusCode: statusCode,
          description: description,
        );
      },
      err: (error) => error,
    );
  }

  Result<Map<String, Object?>, LoginFlowError> _dataObject(
    Map<String, Object?> envelope,
  ) {
    final data = envelope['data'];
    if (data is Map<String, Object?>) {
      return Ok(data);
    }
    return Err(
      ServerResponseInvalid(
        statusCode: statusCode,
        description: 'The envelope\'s "data" is not a JSON object.',
      ),
    );
  }

  Result<List<Map<String, Object?>>, LoginFlowError> _dataList(
    Map<String, Object?> envelope,
  ) {
    final data = envelope['data'];
    if (data is List<Object?> &&
        data.every((entry) => entry is Map<String, Object?>)) {
      return Ok(data.cast<Map<String, Object?>>());
    }
    return Err(
      ServerResponseInvalid(
        statusCode: statusCode,
        description: 'The envelope\'s "data" is not a JSON array.',
      ),
    );
  }
}
