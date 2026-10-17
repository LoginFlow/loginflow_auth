import 'package:loginflow_auth/src/core/json/json_field_reader.dart';

/// A successful token endpoint response (RFC 6749 §5.1), with the members
/// added by OpenID Connect Core §3.1.3.3, RFC 8693 §2.2.1, OpenID Connect
/// Native SSO §3.4 / §4.4 and draft-ietf-oauth-first-party-apps-04 §6.1.
class TokenResponse {
  const TokenResponse({
    required this.accessToken,
    required this.tokenType,
    required this.expiresIn,
    this.refreshToken,
    this.idToken,
    this.scope,
    this.deviceSecret,
    this.issuedTokenType,
    this.authSession,
  });

  factory TokenResponse.fromJson(Map<String, Object?> json) => TokenResponse(
    accessToken: json.requireString('access_token'),
    tokenType: json.requireString('token_type'),
    expiresIn: Duration(seconds: json.requireInt('expires_in')),
    refreshToken: json.optionalString('refresh_token'),
    idToken: json.optionalString('id_token'),
    scope: json.optionalString('scope'),
    deviceSecret: json.optionalString('device_secret'),
    issuedTokenType: json.optionalString('issued_token_type'),
    authSession: json.optionalString('auth_session'),
  );

  final String accessToken;

  /// Case-insensitive (RFC 6749 §7.1): `Bearer`, or `DPoP` for a client
  /// using RFC 9449 (§13).
  final String tokenType;
  final Duration expiresIn;
  final String? refreshToken;
  final String? idToken;
  final String? scope;

  /// OpenID Connect Native SSO §3.4.
  final String? deviceSecret;

  /// RFC 8693 §2.2.1.
  final String? issuedTokenType;

  /// draft-ietf-oauth-first-party-apps-04 §6.1.
  final String? authSession;

  bool get isBearer => tokenType.toLowerCase() == 'bearer';

  /// RFC 9449 §7.1.
  bool get isDpop => tokenType.toLowerCase() == 'dpop';

  TokenResponse copyWith({
    String? accessToken,
    String? tokenType,
    Duration? expiresIn,
    String? refreshToken,
    String? idToken,
    String? scope,
    String? deviceSecret,
    String? issuedTokenType,
    String? authSession,
  }) => TokenResponse(
    accessToken: accessToken ?? this.accessToken,
    tokenType: tokenType ?? this.tokenType,
    expiresIn: expiresIn ?? this.expiresIn,
    refreshToken: refreshToken ?? this.refreshToken,
    idToken: idToken ?? this.idToken,
    scope: scope ?? this.scope,
    deviceSecret: deviceSecret ?? this.deviceSecret,
    issuedTokenType: issuedTokenType ?? this.issuedTokenType,
    authSession: authSession ?? this.authSession,
  );

  Map<String, Object?> toJson() => <String, Object?>{
    'access_token': accessToken,
    'token_type': tokenType,
    'expires_in': expiresIn.inSeconds,
    'refresh_token': ?refreshToken,
    'id_token': ?idToken,
    'scope': ?scope,
    'device_secret': ?deviceSecret,
    'issued_token_type': ?issuedTokenType,
    'auth_session': ?authSession,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TokenResponse &&
          accessToken == other.accessToken &&
          tokenType == other.tokenType &&
          expiresIn == other.expiresIn &&
          refreshToken == other.refreshToken &&
          idToken == other.idToken &&
          scope == other.scope &&
          deviceSecret == other.deviceSecret &&
          issuedTokenType == other.issuedTokenType &&
          authSession == other.authSession;

  @override
  int get hashCode => Object.hash(
    accessToken,
    tokenType,
    expiresIn,
    refreshToken,
    idToken,
    scope,
    deviceSecret,
    issuedTokenType,
    authSession,
  );

  /// Never prints a token.
  @override
  String toString() => 'TokenResponse(tokenType: $tokenType, scope: $scope)';
}
