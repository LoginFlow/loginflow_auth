import 'package:loginflow_auth/src/core/json/json_field_reader.dart';

/// The long-lived part of a session that survives an app restart.
///
/// Access tokens are deliberately absent: they stay in memory on every
/// platform and are re-obtained with the refresh token after a restart.
class StoredSession {
  /// Creates a [StoredSession].
  const StoredSession({
    required this.refreshToken,
    required this.idToken,
    required this.scope,
    this.authSession,
    this.nonce,
    this.isBrowserSessionUsed = false,
    this.isSsoBound = false,
    this.dpopJkt,
    this.organizationId,
  });

  /// Reads a [StoredSession] from its JSON form ([toJson]).
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
    dpopJkt: json.optionalString('dpop_jkt'),
    organizationId: json.optionalString('organization_id'),
  );

  /// The current refresh token; rotated by every refresh.
  final String refreshToken;

  /// The latest validated ID token (also the `id_token_hint` for logout).
  final String idToken;

  /// The granted scopes, space-separated.
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

  /// The RFC 7638 thumbprint of the DPoP key the refresh family is bound to
  /// (the token's `cnf.jkt`, RFC 9449 §6.1), or `null` for a session issued
  /// without DPoP. A restored session whose key is no longer held by the
  /// platform cannot be refreshed and is ended locally.
  final String? dpopJkt;

  /// The organization this app asked for, at sign-in or with the last
  /// `LoginFlowAuth.switchOrganization`, or `null` when the server chose
  /// (`doc/server-contract.md` §17). A step-up opens its authorization in
  /// it, so re-authenticating never changes the active organization.
  final String? organizationId;

  /// A copy of this [StoredSession] with the given fields replaced.
  StoredSession copyWith({
    String? refreshToken,
    String? idToken,
    String? scope,
    String? authSession,
    String? nonce,
    bool? isBrowserSessionUsed,
    bool? isSsoBound,
    String? dpopJkt,
    String? organizationId,
  }) => StoredSession(
    refreshToken: refreshToken ?? this.refreshToken,
    idToken: idToken ?? this.idToken,
    scope: scope ?? this.scope,
    authSession: authSession ?? this.authSession,
    nonce: nonce ?? this.nonce,
    isBrowserSessionUsed: isBrowserSessionUsed ?? this.isBrowserSessionUsed,
    isSsoBound: isSsoBound ?? this.isSsoBound,
    dpopJkt: dpopJkt ?? this.dpopJkt,
    organizationId: organizationId ?? this.organizationId,
  );

  /// The JSON form of this [StoredSession], read back by [StoredSession.fromJson].
  Map<String, Object?> toJson() => <String, Object?>{
    'refresh_token': refreshToken,
    'id_token': idToken,
    'scope': scope,
    'auth_session': ?authSession,
    'nonce': ?nonce,
    'browser_session_used': isBrowserSessionUsed,
    'sso_bound': isSsoBound,
    'dpop_jkt': ?dpopJkt,
    'organization_id': ?organizationId,
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
          isSsoBound == other.isSsoBound &&
          dpopJkt == other.dpopJkt &&
          organizationId == other.organizationId;

  @override
  int get hashCode => Object.hash(
    refreshToken,
    idToken,
    scope,
    authSession,
    nonce,
    isBrowserSessionUsed,
    isSsoBound,
    dpopJkt,
    organizationId,
  );

  @override
  String toString() => 'StoredSession(scope: $scope, ssoBound: $isSsoBound)';
}
