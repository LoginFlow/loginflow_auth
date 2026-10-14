import 'package:loginflow_auth/src/core/session/login_flow_session.dart';
import 'package:loginflow_auth/src/core/session/user_identity.dart';
import 'package:loginflow_auth/src/core/storage/stored_session.dart';

/// The in-memory session: what is stored plus the current access token.
///
/// Internal flow state; the persisted part is [stored], so this holder has no
/// `toJson`/`fromJson`.
class ActiveSession {
  const ActiveSession({
    required this.stored,
    required this.identity,
    this.accessToken,
    this.accessTokenExpiresAt,
  });

  /// How long before `expires_in` the access token is considered stale, so a
  /// request never leaves with a token that expires in flight.
  static const Duration expiryMargin = Duration(seconds: 30);

  final StoredSession stored;
  final UserIdentity identity;
  final String? accessToken;
  final DateTime? accessTokenExpiresAt;

  /// The access token, when it is still usable at [now].
  String? freshAccessToken(DateTime now) {
    final expiresAt = accessTokenExpiresAt;
    if (expiresAt == null || !now.isBefore(expiresAt.subtract(expiryMargin))) {
      return null;
    }
    return accessToken;
  }

  LoginFlowSession toPublic() => LoginFlowSession(
    identity: identity,
    scope: stored.scope,
    isSsoBound: stored.isSsoBound,
  );

  ActiveSession copyWith({
    StoredSession? stored,
    UserIdentity? identity,
    String? accessToken,
    DateTime? accessTokenExpiresAt,
  }) => ActiveSession(
    stored: stored ?? this.stored,
    identity: identity ?? this.identity,
    accessToken: accessToken ?? this.accessToken,
    accessTokenExpiresAt: accessTokenExpiresAt ?? this.accessTokenExpiresAt,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ActiveSession &&
          stored == other.stored &&
          identity == other.identity &&
          accessToken == other.accessToken &&
          accessTokenExpiresAt == other.accessTokenExpiresAt;

  @override
  int get hashCode =>
      Object.hash(stored, identity, accessToken, accessTokenExpiresAt);

  @override
  String toString() => 'ActiveSession(subject: ${identity.subject})';
}
