import 'package:loginflow_auth/src/core/json/json_field_reader.dart';

/// An RP-Initiated Logout request (OpenID Connect RP-Initiated Logout 1.0 §2).
class EndSessionRequest {
  const EndSessionRequest({
    required this.clientId,
    required this.idTokenHint,
    required this.postLogoutRedirectUri,
    required this.state,
  });

  factory EndSessionRequest.fromJson(Map<String, Object?> json) =>
      EndSessionRequest(
        clientId: json.requireString('client_id'),
        idTokenHint: json.requireString('id_token_hint'),
        postLogoutRedirectUri: Uri.parse(
          json.requireString('post_logout_redirect_uri'),
        ),
        state: json.requireString('state'),
      );

  final String clientId;

  /// RECOMMENDED (§2); lets the server skip the confirmation prompt.
  final String idTokenHint;

  /// Must exactly match a registered value (§3).
  final Uri postLogoutRedirectUri;
  final String state;

  Uri toUri(Uri endSessionEndpoint) => endSessionEndpoint.replace(
    queryParameters: <String, String>{
      ...endSessionEndpoint.queryParameters,
      'client_id': clientId,
      'id_token_hint': idTokenHint,
      'post_logout_redirect_uri': postLogoutRedirectUri.toString(),
      'state': state,
    },
  );

  EndSessionRequest copyWith({
    String? clientId,
    String? idTokenHint,
    Uri? postLogoutRedirectUri,
    String? state,
  }) => EndSessionRequest(
    clientId: clientId ?? this.clientId,
    idTokenHint: idTokenHint ?? this.idTokenHint,
    postLogoutRedirectUri: postLogoutRedirectUri ?? this.postLogoutRedirectUri,
    state: state ?? this.state,
  );

  Map<String, Object?> toJson() => <String, Object?>{
    'client_id': clientId,
    'id_token_hint': idTokenHint,
    'post_logout_redirect_uri': postLogoutRedirectUri.toString(),
    'state': state,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is EndSessionRequest &&
          clientId == other.clientId &&
          idTokenHint == other.idTokenHint &&
          postLogoutRedirectUri == other.postLogoutRedirectUri &&
          state == other.state;

  @override
  int get hashCode =>
      Object.hash(clientId, idTokenHint, postLogoutRedirectUri, state);

  @override
  String toString() => 'EndSessionRequest(clientId: $clientId)';
}
