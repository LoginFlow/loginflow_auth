import 'package:loginflow_auth/src/core/error/login_flow_error.dart';
import 'package:loginflow_auth/src/core/http/transport_reply.dart';
import 'package:loginflow_auth/src/core/json/json_field_reader.dart';

/// An OAuth error response body (RFC 6749 §5.2).
class OAuthErrorBody {
  const OAuthErrorBody({
    required this.error,
    this.errorDescription,
    this.errorUri,
  });

  factory OAuthErrorBody.fromJson(Map<String, Object?> json) => OAuthErrorBody(
    error: json.requireString('error'),
    errorDescription: json.optionalString('error_description'),
    errorUri: json.optionalString('error_uri'),
  );

  final String error;
  final String? errorDescription;
  final String? errorUri;

  OAuthErrorBody copyWith({
    String? error,
    String? errorDescription,
    String? errorUri,
  }) => OAuthErrorBody(
    error: error ?? this.error,
    errorDescription: errorDescription ?? this.errorDescription,
    errorUri: errorUri ?? this.errorUri,
  );

  Map<String, Object?> toJson() => <String, Object?>{
    'error': error,
    'error_description': ?errorDescription,
    'error_uri': ?errorUri,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is OAuthErrorBody &&
          error == other.error &&
          errorDescription == other.errorDescription &&
          errorUri == other.errorUri;

  @override
  int get hashCode => Object.hash(error, errorDescription, errorUri);
}

/// Maps a non-success reply to the matching [LoginFlowError].
extension FailedReplyMapping on TransportReply {
  LoginFlowError toLoginFlowError() {
    if (statusCode == 429) {
      return RateLimited(retryAfter: retryAfter);
    }
    return jsonObject().when(
      ok: (json) {
        try {
          final body = OAuthErrorBody.fromJson(json);
          return OAuthProtocolError(
            statusCode: statusCode,
            code: body.error,
            description: body.errorDescription,
          );
        } on FormatException catch (error) {
          return ServerResponseInvalid(
            statusCode: statusCode,
            description: error.message,
          );
        }
      },
      err: (error) => error,
    );
  }
}
