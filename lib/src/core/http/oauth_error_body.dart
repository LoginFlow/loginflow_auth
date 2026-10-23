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
    final challengeError = _challengeError;
    if (body.trim().isEmpty && challengeError != null) {
      return challengeError;
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

  /// A protected resource refuses a token with no body, only its
  /// `WWW-Authenticate` challenge (RFC 6750 §3, RFC 9449 §7.1): e.g.
  /// `Bearer error="invalid_token"`. `null` when there is no `error`
  /// parameter to read.
  OAuthProtocolError? get _challengeError {
    final challenge = wwwAuthenticate;
    if (challenge == null) {
      return null;
    }
    final error = _challengeParameter(challenge, 'error');
    if (error == null) {
      return null;
    }
    return OAuthProtocolError(
      statusCode: statusCode,
      code: error,
      description: _challengeParameter(challenge, 'error_description'),
    );
  }

  static String? _challengeParameter(String challenge, String name) =>
      RegExp('(?:^|[\\s,])$name="([^"]*)"').firstMatch(challenge)?.group(1);
}
