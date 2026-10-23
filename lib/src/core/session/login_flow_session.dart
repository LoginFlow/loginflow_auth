import 'package:loginflow_auth/src/core/json/json_field_reader.dart';
import 'package:loginflow_auth/src/core/session/access_token_claims.dart';
import 'package:loginflow_auth/src/core/session/user_identity.dart';

/// The signed-in session as the app sees it. Tokens are not part of it: ask
/// `LoginFlowAuth.accessTokenFor(api)` for a valid access token.
class LoginFlowSession {
  const LoginFlowSession({
    required this.identity,
    required this.scope,
    this.isSsoBound = false,
    this.accessClaims = const <String, AccessTokenClaims>{},
  });

  factory LoginFlowSession.fromJson(Map<String, Object?> json) {
    final identity = json.optionalObject('identity');
    if (identity == null) {
      throw const FormatException('Field "identity" is required.');
    }
    final claims =
        json.optionalObject('access_claims') ?? const <String, Object?>{};
    return LoginFlowSession(
      identity: UserIdentity.fromJson(identity),
      scope: json.requireString('scope'),
      isSsoBound: json.optionalBool('sso_bound', absent: false),
      accessClaims: Map<String, AccessTokenClaims>.unmodifiable(
        <String, AccessTokenClaims>{
          for (final api in claims.keys)
            api: AccessTokenClaims.fromJson(
              claims.optionalObject(api) ??
                  (throw FormatException(
                    'Field "access_claims.$api" must be an object.',
                  )),
            ),
        },
      ),
    );
  }

  final UserIdentity identity;

  /// Space-separated granted scopes.
  final String scope;

  /// Participates in Native SSO with the publisher's other apps.
  final bool isSsoBound;

  /// The organization and permissions of each API token the app obtained
  /// so far, keyed by API audience (`LoginFlowConfig.apis`). An API appears
  /// after its first `LoginFlowAuth.accessTokenFor`, and the map empties
  /// when the active organization changes.
  ///
  /// UI ONLY: decoded from the tokens without verifying them. Every access
  /// decision belongs to the API that verifies the token.
  final Map<String, AccessTokenClaims> accessClaims;

  LoginFlowSession copyWith({
    UserIdentity? identity,
    String? scope,
    bool? isSsoBound,
    Map<String, AccessTokenClaims>? accessClaims,
  }) => LoginFlowSession(
    identity: identity ?? this.identity,
    scope: scope ?? this.scope,
    isSsoBound: isSsoBound ?? this.isSsoBound,
    accessClaims: accessClaims ?? this.accessClaims,
  );

  Map<String, Object?> toJson() => <String, Object?>{
    'identity': identity.toJson(),
    'scope': scope,
    'sso_bound': isSsoBound,
    'access_claims': <String, Object?>{
      for (final MapEntry(key: api, value: claims) in accessClaims.entries)
        api: claims.toJson(),
    },
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LoginFlowSession &&
          identity == other.identity &&
          scope == other.scope &&
          isSsoBound == other.isSsoBound &&
          accessClaims.length == other.accessClaims.length &&
          accessClaims.entries.every(
            (entry) => other.accessClaims[entry.key] == entry.value,
          );

  @override
  int get hashCode => Object.hash(
    identity,
    scope,
    isSsoBound,
    Object.hashAllUnordered(
      accessClaims.entries.map((entry) => Object.hash(entry.key, entry.value)),
    ),
  );
}
