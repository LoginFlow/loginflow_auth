import 'package:loginflow_auth/src/core/json/json_field_reader.dart';

/// The long-lived part of a session that survives an app restart.
///
/// Access tokens are deliberately absent: they stay in memory on every
/// platform and are re-obtained with the refresh token after a restart.
class StoredSession {
  const StoredSession({
    required this.refreshToken,
    required this.idToken,
    required this.scope,
    this.authSession,
    this.nonce,
    this.isBrowserSessionUsed = false,
    this.isSsoBound = false,
  });

  factory StoredSession.fromJson(Map<String, Object?> json) => StoredSession(
    refreshToken: json.requireString('refresh_token'),
    idToken: json.requireString('id_token'),
    scope: json.requireString('scope'),
    authSession: json.optionalString('auth_session'),
    nonce: json.optionalString('nonce'),
    isBrowserSessionUsed: json.optionalBool(
      'browser_session_used',
      absent: false,
    ),
    isSsoBound: json.optionalBool('sso_bound', absent: false),
  );

  final String refreshToken;

  /// The latest validated ID token (also the `id_token_hint` for logout).
  final String idToken;
  final String scope;

  /// The first-party-apps `auth_session`, kept after sign-in for step-up
  /// (draft-ietf-oauth-first-party-apps-04 §5.3.1) and discarded on logout.
  final String? authSession;

  /// The nonce of the original authentication (OpenID Connect Core §12.2).
  final String? nonce;

  /// A system-browser step created an authorization-server browser session,
  /// so RP-initiated logout is meaningful.
  final bool isBrowserSessionUsed;

  /// The session was issued with `device_sso` and has a shared device secret.
  final bool isSsoBound;

  StoredSession copyWith({
    String? refreshToken,
    String? idToken,
    String? scope,
    String? authSession,
    String? nonce,
    bool? isBrowserSessionUsed,
    bool? isSsoBound,
  }) => StoredSession(
    refreshToken: refreshToken ?? this.refreshToken,
    idToken: idToken ?? this.idToken,
    scope: scope ?? this.scope,
    authSession: authSession ?? this.authSession,
    nonce: nonce ?? this.nonce,
    isBrowserSessionUsed: isBrowserSessionUsed ?? this.isBrowserSessionUsed,
    isSsoBound: isSsoBound ?? this.isSsoBound,
  );

  Map<String, Object?> toJson() => <String, Object?>{
    'refresh_token': refreshToken,
    'id_token': idToken,
    'scope': scope,
    'auth_session': ?authSession,
    'nonce': ?nonce,
    'browser_session_used': isBrowserSessionUsed,
    'sso_bound': isSsoBound,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StoredSession &&
          refreshToken == other.refreshToken &&
          idToken == other.idToken &&
          scope == other.scope &&
          authSession == other.authSession &&
          nonce == other.nonce &&
          isBrowserSessionUsed == other.isBrowserSessionUsed &&
          isSsoBound == other.isSsoBound;

  @override
  int get hashCode => Object.hash(
    refreshToken,
    idToken,
    scope,
    authSession,
    nonce,
    isBrowserSessionUsed,
    isSsoBound,
  );

  @override
  String toString() => 'StoredSession(scope: $scope, ssoBound: $isSsoBound)';
}
