import 'package:loginflow_auth/src/core/crypto/pkce_pair.dart';
import 'package:loginflow_auth/src/core/json/json_field_reader.dart';

/// A front-channel authorization request for the system browser
/// (RFC 6749 §4.1.1, RFC 7636 §4.3, OpenID Connect Core §3.1.2.1), or a
/// reference to a request the server already pushed (RFC 9126 §4).
class AuthorizationRequest {
  const AuthorizationRequest({
    required this.clientId,
    required this.redirectUri,
    required this.scope,
    required this.state,
    required this.nonce,
    required this.codeChallenge,
    this.prompt,
    this.loginHint,
    this.requestUri,
  });

  factory AuthorizationRequest.fromJson(Map<String, Object?> json) =>
      AuthorizationRequest(
        clientId: json.requireString('client_id'),
        redirectUri: Uri.parse(json.requireString('redirect_uri')),
        scope: json.requireString('scope'),
        state: json.requireString('state'),
        nonce: json.requireString('nonce'),
        codeChallenge: json.requireString('code_challenge'),
        prompt: json.optionalString('prompt'),
        loginHint: json.optionalString('login_hint'),
        requestUri: json.optionalString('request_uri'),
      );

  final String clientId;
  final Uri redirectUri;
  final String scope;
  final String state;
  final String nonce;
  final String codeChallenge;

  /// `none` for silent SSO, `login`, `create`, ...
  final String? prompt;
  final String? loginHint;

  /// When set, the URL carries only `client_id` and `request_uri`
  /// (RFC 9126 §4): every other parameter was pushed by the server.
  final String? requestUri;

  Uri toUri(Uri authorizationEndpoint) {
    final pushed = requestUri;
    final parameters = pushed == null
        ? <String, String>{
            'response_type': 'code',
            'client_id': clientId,
            'redirect_uri': redirectUri.toString(),
            'scope': scope,
            'state': state,
            'nonce': nonce,
            'code_challenge': codeChallenge,
            'code_challenge_method': PkcePair.method,
            'prompt': ?prompt,
            'login_hint': ?loginHint,
          }
        : <String, String>{'client_id': clientId, 'request_uri': pushed};
    return authorizationEndpoint.replace(
      queryParameters: <String, String>{
        ...authorizationEndpoint.queryParameters,
        ...parameters,
      },
    );
  }

  AuthorizationRequest copyWith({
    String? clientId,
    Uri? redirectUri,
    String? scope,
    String? state,
    String? nonce,
    String? codeChallenge,
    String? prompt,
    String? loginHint,
    String? requestUri,
  }) => AuthorizationRequest(
    clientId: clientId ?? this.clientId,
    redirectUri: redirectUri ?? this.redirectUri,
    scope: scope ?? this.scope,
    state: state ?? this.state,
    nonce: nonce ?? this.nonce,
    codeChallenge: codeChallenge ?? this.codeChallenge,
    prompt: prompt ?? this.prompt,
    loginHint: loginHint ?? this.loginHint,
    requestUri: requestUri ?? this.requestUri,
  );

  Map<String, Object?> toJson() => <String, Object?>{
    'client_id': clientId,
    'redirect_uri': redirectUri.toString(),
    'scope': scope,
    'state': state,
    'nonce': nonce,
    'code_challenge': codeChallenge,
    'prompt': ?prompt,
    'login_hint': ?loginHint,
    'request_uri': ?requestUri,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AuthorizationRequest &&
          clientId == other.clientId &&
          redirectUri == other.redirectUri &&
          scope == other.scope &&
          state == other.state &&
          nonce == other.nonce &&
          codeChallenge == other.codeChallenge &&
          prompt == other.prompt &&
          loginHint == other.loginHint &&
          requestUri == other.requestUri;

  @override
  int get hashCode => Object.hash(
    clientId,
    redirectUri,
    scope,
    state,
    nonce,
    codeChallenge,
    prompt,
    loginHint,
    requestUri,
  );
}
