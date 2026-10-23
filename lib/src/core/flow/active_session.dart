import 'package:loginflow_auth/src/core/flow/issued_access_token.dart';
import 'package:loginflow_auth/src/core/session/access_token_claims.dart';
import 'package:loginflow_auth/src/core/session/login_flow_session.dart';
import 'package:loginflow_auth/src/core/session/user_identity.dart';
import 'package:loginflow_auth/src/core/storage/stored_session.dart';

/// The in-memory session: what is stored plus the access tokens it holds.
///
/// Internal flow state; the persisted part is [stored], so this holder has no
/// `toJson`/`fromJson`.
class ActiveSession {
  const ActiveSession({
    required this.stored,
    required this.identity,
    this.sessionToken,
    this.loginFlowToken,
    this.apiTokens = const <String, IssuedAccessToken>{},
  });

  final StoredSession stored;
  final UserIdentity identity;

  /// The session's own access token (issued without `resource`), for
  /// LoginFlow's endpoints: passkeys, logout, organizations.
  final IssuedAccessToken? sessionToken;

  /// LoginFlow's own token, asked with `resource=<issuer>` (`aud` = the
  /// issuer, no permissions), for the members API — which refuses any other
  /// audience. Kept apart from [apiTokens]: it is not an API of the app.
  final IssuedAccessToken? loginFlowToken;

  /// One token per API the app asked for, keyed by its audience (RFC 8707
  /// `resource`). All of them are issued for the active organization.
  final Map<String, IssuedAccessToken> apiTokens;

  String? freshSessionToken(DateTime now) => sessionToken?.freshValue(now);

  String? freshApiToken(String api, DateTime now) =>
      apiTokens[api]?.freshValue(now);

  String? freshLoginFlowToken(DateTime now) => loginFlowToken?.freshValue(now);

  /// This session with [token] cached for [api].
  ActiveSession withApiToken(String api, IssuedAccessToken token) => copyWith(
    apiTokens: Map<String, IssuedAccessToken>.unmodifiable(
      <String, IssuedAccessToken>{...apiTokens, api: token},
    ),
  );

  LoginFlowSession toPublic() => LoginFlowSession(
    identity: identity,
    scope: stored.scope,
    isSsoBound: stored.isSsoBound,
    accessClaims: Map<String, AccessTokenClaims>.unmodifiable(
      <String, AccessTokenClaims>{
        for (final MapEntry(key: api, value: token) in apiTokens.entries)
          api: ?token.claims,
      },
    ),
  );

  ActiveSession copyWith({
    StoredSession? stored,
    UserIdentity? identity,
    IssuedAccessToken? sessionToken,
    IssuedAccessToken? loginFlowToken,
    Map<String, IssuedAccessToken>? apiTokens,
  }) => ActiveSession(
    stored: stored ?? this.stored,
    identity: identity ?? this.identity,
    sessionToken: sessionToken ?? this.sessionToken,
    loginFlowToken: loginFlowToken ?? this.loginFlowToken,
    apiTokens: apiTokens ?? this.apiTokens,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ActiveSession &&
          stored == other.stored &&
          identity == other.identity &&
          sessionToken == other.sessionToken &&
          loginFlowToken == other.loginFlowToken &&
          _sameTokens(apiTokens, other.apiTokens);

  @override
  int get hashCode => Object.hash(
    stored,
    identity,
    sessionToken,
    loginFlowToken,
    Object.hashAllUnordered(apiTokens.entries.map(_entryHash)),
  );

  @override
  String toString() => 'ActiveSession(subject: ${identity.subject})';

  static bool _sameTokens(
    Map<String, IssuedAccessToken> first,
    Map<String, IssuedAccessToken> second,
  ) =>
      first.length == second.length &&
      first.entries.every((entry) => second[entry.key] == entry.value);

  static int _entryHash(MapEntry<String, IssuedAccessToken> entry) =>
      Object.hash(entry.key, entry.value);
}
