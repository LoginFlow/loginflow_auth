import 'package:loginflow_auth/src/core/error/login_flow_error.dart';
import 'package:loginflow_auth/src/core/http/transport_reply.dart';
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
