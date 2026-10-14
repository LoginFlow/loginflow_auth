import 'package:loginflow_auth/src/core/json/json_field_reader.dart';
import 'package:loginflow_auth/src/core/session/user_identity.dart';

/// The signed-in session as the app sees it. Tokens are not part of it: ask
/// `LoginFlowAuth.accessToken()` for a valid access token.
class LoginFlowSession {
  const LoginFlowSession({
    required this.identity,
    required this.scope,
    this.isSsoBound = false,
  });

  factory LoginFlowSession.fromJson(Map<String, Object?> json) {
    final identity = json.optionalObject('identity');
    if (identity == null) {
      throw const FormatException('Field "identity" is required.');
    }
    return LoginFlowSession(
      identity: UserIdentity.fromJson(identity),
      scope: json.requireString('scope'),
      isSsoBound: json.optionalBool('sso_bound', absent: false),
    );
  }

  final UserIdentity identity;

  /// Space-separated granted scopes.
  final String scope;

  /// Participates in Native SSO with the publisher's other apps.
  final bool isSsoBound;

  LoginFlowSession copyWith({
    UserIdentity? identity,
    String? scope,
    bool? isSsoBound,
  }) => LoginFlowSession(
    identity: identity ?? this.identity,
    scope: scope ?? this.scope,
    isSsoBound: isSsoBound ?? this.isSsoBound,
  );

  Map<String, Object?> toJson() => <String, Object?>{
    'identity': identity.toJson(),
    'scope': scope,
    'sso_bound': isSsoBound,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LoginFlowSession &&
          identity == other.identity &&
          scope == other.scope &&
          isSsoBound == other.isSsoBound;

  @override
  int get hashCode => Object.hash(identity, scope, isSsoBound);
}
