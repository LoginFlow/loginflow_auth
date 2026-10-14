/// A token endpoint request body (RFC 6749 §4.1.3, §6; RFC 8693 §2.1).
///
/// Grants are request payloads serialized only to form fields; they are never
/// stored, so they have no `toJson`/`fromJson`, and `toString` never prints
/// secrets.
sealed class TokenGrant {
  const TokenGrant();

  /// Public clients authenticate with `client_id` only
  /// (`token_endpoint_auth_method=none`, RFC 7591 §2; RFC 6749 §3.2.1).
  Map<String, String> toFormFields({required String clientId});

  @override
  String toString() => '$runtimeType(<redacted>)';
}

/// `authorization_code` with PKCE (RFC 6749 §4.1.3, RFC 7636 §4.5).
final class AuthorizationCodeGrant extends TokenGrant {
  const AuthorizationCodeGrant({
    required this.code,
    required this.codeVerifier,
    this.redirectUri,
    this.deviceSecret,
  });

  final String code;
  final String codeVerifier;

  /// Sent only when the code came back through a browser redirect
  /// (RFC 6749 §4.1.3). Codes issued by the challenge endpoint have no
  /// redirect (draft-ietf-oauth-first-party-apps-04 §6).
  final Uri? redirectUri;

  /// The current device secret, which the client MUST send when it holds one
  /// (OpenID Connect Native SSO §3.3).
  final String? deviceSecret;

  AuthorizationCodeGrant copyWith({
    String? code,
    String? codeVerifier,
    Uri? redirectUri,
    String? deviceSecret,
  }) => AuthorizationCodeGrant(
    code: code ?? this.code,
    codeVerifier: codeVerifier ?? this.codeVerifier,
    redirectUri: redirectUri ?? this.redirectUri,
    deviceSecret: deviceSecret ?? this.deviceSecret,
  );

  @override
  Map<String, String> toFormFields({required String clientId}) =>
      <String, String>{
        'grant_type': 'authorization_code',
        'client_id': clientId,
        'code': code,
        'code_verifier': codeVerifier,
        'redirect_uri': ?redirectUri?.toString(),
        'device_secret': ?deviceSecret,
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AuthorizationCodeGrant &&
          code == other.code &&
          codeVerifier == other.codeVerifier &&
          redirectUri == other.redirectUri &&
          deviceSecret == other.deviceSecret;

  @override
  int get hashCode =>
      Object.hash(code, codeVerifier, redirectUri, deviceSecret);
}

/// `refresh_token` (RFC 6749 §6).
final class RefreshTokenGrant extends TokenGrant {
  const RefreshTokenGrant({required this.refreshToken, this.deviceSecret});

  final String refreshToken;

  /// SHOULD be sent so the server can rotate it (Native SSO §3.3).
  final String? deviceSecret;

  RefreshTokenGrant copyWith({String? refreshToken, String? deviceSecret}) =>
      RefreshTokenGrant(
        refreshToken: refreshToken ?? this.refreshToken,
        deviceSecret: deviceSecret ?? this.deviceSecret,
      );

  @override
  Map<String, String> toFormFields({required String clientId}) =>
      <String, String>{
        'grant_type': 'refresh_token',
        'client_id': clientId,
        'refresh_token': refreshToken,
        'device_secret': ?deviceSecret,
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RefreshTokenGrant &&
          refreshToken == other.refreshToken &&
          deviceSecret == other.deviceSecret;

  @override
  int get hashCode => Object.hash(refreshToken, deviceSecret);
}

/// The OpenID Connect Native SSO token exchange (Native SSO §4.1, RFC 8693).
final class NativeSsoExchangeGrant extends TokenGrant {
  const NativeSsoExchangeGrant({
    required this.idToken,
    required this.deviceSecret,
    required this.audience,
    required this.scope,
  });

  static const String grantType =
      'urn:ietf:params:oauth:grant-type:token-exchange';

  /// RFC 8693 §3 registers `..._id_token` with an underscore; Native SSO
  /// §4.2's example uses a hyphen, the registered value wins.
  static const String idTokenType = 'urn:ietf:params:oauth:token-type:id_token';
  static const String deviceSecretType =
      'urn:openid:params:token-type:device-secret';

  /// The shared ID token (subject_token).
  final String idToken;

  /// The shared device secret (actor_token).
  final String deviceSecret;

  /// The issuer identifier (Native SSO §4.1).
  final String audience;

  /// Must include `openid`.
  final String scope;

  NativeSsoExchangeGrant copyWith({
    String? idToken,
    String? deviceSecret,
    String? audience,
    String? scope,
  }) => NativeSsoExchangeGrant(
    idToken: idToken ?? this.idToken,
    deviceSecret: deviceSecret ?? this.deviceSecret,
    audience: audience ?? this.audience,
    scope: scope ?? this.scope,
  );

  @override
  Map<String, String> toFormFields({required String clientId}) =>
      <String, String>{
        'grant_type': grantType,
        'client_id': clientId,
        'audience': audience,
        'subject_token': idToken,
        'subject_token_type': idTokenType,
        'actor_token': deviceSecret,
        'actor_token_type': deviceSecretType,
        'scope': scope,
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is NativeSsoExchangeGrant &&
          idToken == other.idToken &&
          deviceSecret == other.deviceSecret &&
          audience == other.audience &&
          scope == other.scope;

  @override
  int get hashCode => Object.hash(idToken, deviceSecret, audience, scope);
}
