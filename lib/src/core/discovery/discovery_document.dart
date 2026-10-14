import 'package:loginflow_auth/src/core/json/json_field_reader.dart';
import 'package:loginflow_auth/src/core/json/list_equality.dart';

/// The fields of `{issuer}/.well-known/openid-configuration` that the library
/// uses (OpenID Connect Discovery 1.0 §3, RFC 8414 §2, plus the extensions
/// listed in `doc/server-contract.md`).
class DiscoveryDocument {
  const DiscoveryDocument({
    required this.issuer,
    required this.authorizationEndpoint,
    required this.tokenEndpoint,
    required this.jwksUri,
    required this.idTokenSigningAlgorithms,
    required this.codeChallengeMethods,
    this.authorizationChallengeEndpoint,
    this.revocationEndpoint,
    this.endSessionEndpoint,
    this.grantTypes = const <String>[],
    this.isNativeSsoSupported = false,
    this.isIssuerParameterSupported = false,
    this.loginOptionsEndpoint,
    this.deviceLogoutEndpoint,
    this.globalLogoutEndpoint,
  });

  factory DiscoveryDocument.fromJson(Map<String, Object?> json) =>
      DiscoveryDocument(
        issuer: json.requireString('issuer'),
        authorizationEndpoint: _uri(json, 'authorization_endpoint'),
        tokenEndpoint: _uri(json, 'token_endpoint'),
        jwksUri: _uri(json, 'jwks_uri'),
        idTokenSigningAlgorithms: json.stringList(
          'id_token_signing_alg_values_supported',
        ),
        codeChallengeMethods: json.stringList(
          'code_challenge_methods_supported',
        ),
        authorizationChallengeEndpoint: _optionalUri(
          json,
          'authorization_challenge_endpoint',
        ),
        revocationEndpoint: _optionalUri(json, 'revocation_endpoint'),
        endSessionEndpoint: _optionalUri(json, 'end_session_endpoint'),
        grantTypes: json.stringList('grant_types_supported'),
        isNativeSsoSupported: json.optionalBool(
          'native_sso_supported',
          absent: false,
        ),
        isIssuerParameterSupported: json.optionalBool(
          'authorization_response_iss_parameter_supported',
          absent: false,
        ),
        loginOptionsEndpoint: _optionalUri(
          json,
          'loginflow_login_options_endpoint',
        ),
        deviceLogoutEndpoint: _optionalUri(
          json,
          'loginflow_device_logout_endpoint',
        ),
        globalLogoutEndpoint: _optionalUri(
          json,
          'loginflow_global_logout_endpoint',
        ),
      );

  /// Grant type of the OpenID Connect Native SSO token exchange (RFC 8693).
  static const String tokenExchangeGrant =
      'urn:ietf:params:oauth:grant-type:token-exchange';

  final String issuer;
  final Uri authorizationEndpoint;
  final Uri tokenEndpoint;
  final Uri jwksUri;
  final List<String> idTokenSigningAlgorithms;
  final List<String> codeChallengeMethods;

  /// draft-ietf-oauth-first-party-apps-04 §8.
  final Uri? authorizationChallengeEndpoint;

  /// RFC 7009 / RFC 8414 §2.
  final Uri? revocationEndpoint;

  /// OpenID Connect RP-Initiated Logout 1.0 §2.1.
  final Uri? endSessionEndpoint;
  final List<String> grantTypes;

  /// OpenID Connect Native SSO for Mobile Apps 1.0 §5.
  final bool isNativeSsoSupported;

  /// RFC 9207 §3.
  final bool isIssuerParameterSupported;

  /// LoginFlow extension: the login methods enabled for a client.
  final Uri? loginOptionsEndpoint;

  /// LoginFlow extension: ends the device session (`sid`).
  final Uri? deviceLogoutEndpoint;

  /// LoginFlow extension: ends every session of the user in the company.
  final Uri? globalLogoutEndpoint;

  bool get supportsS256 => codeChallengeMethods.contains('S256');

  bool get supportsTokenExchange => grantTypes.contains(tokenExchangeGrant);

  static Uri _uri(Map<String, Object?> json, String field) =>
      Uri.parse(json.requireString(field));

  static Uri? _optionalUri(Map<String, Object?> json, String field) {
    final value = json.optionalString(field);
    return value == null ? null : Uri.parse(value);
  }

  DiscoveryDocument copyWith({
    String? issuer,
    Uri? authorizationEndpoint,
    Uri? tokenEndpoint,
    Uri? jwksUri,
    List<String>? idTokenSigningAlgorithms,
    List<String>? codeChallengeMethods,
    Uri? authorizationChallengeEndpoint,
    Uri? revocationEndpoint,
    Uri? endSessionEndpoint,
    List<String>? grantTypes,
    bool? isNativeSsoSupported,
    bool? isIssuerParameterSupported,
    Uri? loginOptionsEndpoint,
    Uri? deviceLogoutEndpoint,
    Uri? globalLogoutEndpoint,
  }) => DiscoveryDocument(
    issuer: issuer ?? this.issuer,
    authorizationEndpoint: authorizationEndpoint ?? this.authorizationEndpoint,
    tokenEndpoint: tokenEndpoint ?? this.tokenEndpoint,
    jwksUri: jwksUri ?? this.jwksUri,
    idTokenSigningAlgorithms:
        idTokenSigningAlgorithms ?? this.idTokenSigningAlgorithms,
    codeChallengeMethods: codeChallengeMethods ?? this.codeChallengeMethods,
    authorizationChallengeEndpoint:
        authorizationChallengeEndpoint ?? this.authorizationChallengeEndpoint,
    revocationEndpoint: revocationEndpoint ?? this.revocationEndpoint,
    endSessionEndpoint: endSessionEndpoint ?? this.endSessionEndpoint,
    grantTypes: grantTypes ?? this.grantTypes,
    isNativeSsoSupported: isNativeSsoSupported ?? this.isNativeSsoSupported,
    isIssuerParameterSupported:
        isIssuerParameterSupported ?? this.isIssuerParameterSupported,
    loginOptionsEndpoint: loginOptionsEndpoint ?? this.loginOptionsEndpoint,
    deviceLogoutEndpoint: deviceLogoutEndpoint ?? this.deviceLogoutEndpoint,
    globalLogoutEndpoint: globalLogoutEndpoint ?? this.globalLogoutEndpoint,
  );

  Map<String, Object?> toJson() => <String, Object?>{
    'issuer': issuer,
    'authorization_endpoint': authorizationEndpoint.toString(),
    'token_endpoint': tokenEndpoint.toString(),
    'jwks_uri': jwksUri.toString(),
    'id_token_signing_alg_values_supported': idTokenSigningAlgorithms,
    'code_challenge_methods_supported': codeChallengeMethods,
    'authorization_challenge_endpoint': ?authorizationChallengeEndpoint
        ?.toString(),
    'revocation_endpoint': ?revocationEndpoint?.toString(),
    'end_session_endpoint': ?endSessionEndpoint?.toString(),
    'grant_types_supported': grantTypes,
    'native_sso_supported': isNativeSsoSupported,
    'authorization_response_iss_parameter_supported':
        isIssuerParameterSupported,
    'loginflow_login_options_endpoint': ?loginOptionsEndpoint?.toString(),
    'loginflow_device_logout_endpoint': ?deviceLogoutEndpoint?.toString(),
    'loginflow_global_logout_endpoint': ?globalLogoutEndpoint?.toString(),
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DiscoveryDocument &&
          issuer == other.issuer &&
          authorizationEndpoint == other.authorizationEndpoint &&
          tokenEndpoint == other.tokenEndpoint &&
          jwksUri == other.jwksUri &&
          idTokenSigningAlgorithms.hasSameValues(
            other.idTokenSigningAlgorithms,
          ) &&
          codeChallengeMethods.hasSameValues(other.codeChallengeMethods) &&
          authorizationChallengeEndpoint ==
              other.authorizationChallengeEndpoint &&
          revocationEndpoint == other.revocationEndpoint &&
          endSessionEndpoint == other.endSessionEndpoint &&
          grantTypes.hasSameValues(other.grantTypes) &&
          isNativeSsoSupported == other.isNativeSsoSupported &&
          isIssuerParameterSupported == other.isIssuerParameterSupported &&
          loginOptionsEndpoint == other.loginOptionsEndpoint &&
          deviceLogoutEndpoint == other.deviceLogoutEndpoint &&
          globalLogoutEndpoint == other.globalLogoutEndpoint;

  @override
  int get hashCode => Object.hash(
    issuer,
    authorizationEndpoint,
    tokenEndpoint,
    jwksUri,
    idTokenSigningAlgorithms.valuesHash,
    codeChallengeMethods.valuesHash,
    authorizationChallengeEndpoint,
    revocationEndpoint,
    endSessionEndpoint,
    grantTypes.valuesHash,
    isNativeSsoSupported,
    isIssuerParameterSupported,
    loginOptionsEndpoint,
    deviceLogoutEndpoint,
    globalLogoutEndpoint,
  );
}
