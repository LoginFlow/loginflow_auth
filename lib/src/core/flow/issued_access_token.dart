import 'package:loginflow_auth/src/core/session/access_token_claims.dart';

/// One access token held in memory: the session's own token, or the token
/// of one API (RFC 8707 `resource`).
///
/// Internal flow state; access tokens are never persisted, so this holder
/// has no `toJson`/`fromJson`.
class IssuedAccessToken {
  const IssuedAccessToken({
    required this.value,
    required this.expiresAt,
    this.claims,
  });

  /// [value] with its claims decoded (UI only, unverified), expiring
  /// [expiresIn] after [now].
  factory IssuedAccessToken.issued({
    required String value,
    required DateTime now,
    required Duration expiresIn,
  }) => IssuedAccessToken(
    value: value,
    expiresAt: now.add(expiresIn),
    claims: AccessTokenClaims.decode(value),
  );

  /// How long before `expires_in` the token is considered stale, so a
  /// request never leaves with a token that expires in flight.
  static const Duration expiryMargin = Duration(seconds: 30);

  final String value;
  final DateTime expiresAt;

  /// `null` for an opaque token.
  final AccessTokenClaims? claims;

  /// The token, when it is still usable at [now].
  String? freshValue(DateTime now) =>
      now.isBefore(expiresAt.subtract(expiryMargin)) ? value : null;

  IssuedAccessToken copyWith({
    String? value,
    DateTime? expiresAt,
    AccessTokenClaims? claims,
  }) => IssuedAccessToken(
    value: value ?? this.value,
    expiresAt: expiresAt ?? this.expiresAt,
    claims: claims ?? this.claims,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is IssuedAccessToken &&
          value == other.value &&
          expiresAt == other.expiresAt &&
          claims == other.claims;

  @override
  int get hashCode => Object.hash(value, expiresAt, claims);

  /// Never prints the token.
  @override
  String toString() => 'IssuedAccessToken(expiresAt: $expiresAt)';
}
