import 'package:loginflow_auth/src/core/protocol/challenge/challenge_authorization_parameters.dart';
import 'package:loginflow_auth/src/core/protocol/challenge/challenge_input.dart';

/// One POST to the Authorization Challenge Endpoint
/// (draft-ietf-oauth-first-party-apps-04 §5.1).
///
/// A request payload serialized only to form fields; never stored, so it has
/// no `toJson`/`fromJson`.
class ChallengeRequest {
  const ChallengeRequest({
    required this.clientId,
    this.authSession,
    this.authorization,
    this.input,
  });

  /// Public clients identify themselves with `client_id` (RFC 6749 §2.3,
  /// first-party-apps §5.1 "REQUIRED if the client is not authenticating").
  final String clientId;
  final String? authSession;

  /// Present on the request that starts an authorization.
  final ChallengeAuthorizationParameters? authorization;
  final ChallengeInput? input;

  Map<String, String> toFormFields() => <String, String>{
    'client_id': clientId,
    'response_type': 'code',
    'auth_session': ?authSession,
    ...?authorization?.toFormFields(),
    ...?input?.toFormFields(),
  };

  ChallengeRequest copyWith({
    String? clientId,
    String? authSession,
    ChallengeAuthorizationParameters? authorization,
    ChallengeInput? input,
  }) => ChallengeRequest(
    clientId: clientId ?? this.clientId,
    authSession: authSession ?? this.authSession,
    authorization: authorization ?? this.authorization,
    input: input ?? this.input,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ChallengeRequest &&
          clientId == other.clientId &&
          authSession == other.authSession &&
          authorization == other.authorization &&
          input == other.input;

  @override
  int get hashCode => Object.hash(clientId, authSession, authorization, input);
}
