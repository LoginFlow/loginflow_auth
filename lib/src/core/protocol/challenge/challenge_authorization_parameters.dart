import 'package:loginflow_auth/src/core/crypto/pkce_pair.dart';
import 'package:loginflow_auth/src/core/json/json_field_reader.dart';
import 'package:loginflow_auth/src/core/json/list_equality.dart';

/// The authorization-request parameters that open a new authorization in the
/// challenge flow (draft-ietf-oauth-first-party-apps-04 §4.1 "MUST accept the
/// authorization request parameters", §5.1).
///
/// They are sent once, on the request that starts an authorization; the
/// server binds them to the `auth_session` and later requests of the same
/// authorization only carry `auth_session` and step parameters.
class ChallengeAuthorizationParameters {
  const ChallengeAuthorizationParameters({
    required this.scope,
    required this.codeChallenge,
    required this.nonce,
    this.acrValues = const <String>[],
    this.maxAge,
    this.redirectUri,
    this.state,
    this.prompt,
    this.uiLocales = const <String>[],
    this.idTokenHint,
    this.organization,
  });

  factory ChallengeAuthorizationParameters.fromJson(Map<String, Object?> json) {
    final maxAge = json.optionalInt('max_age');
    final redirectUri = json.optionalString('redirect_uri');
    return ChallengeAuthorizationParameters(
      scope: json.requireString('scope'),
      codeChallenge: json.requireString('code_challenge'),
      nonce: json.requireString('nonce'),
      acrValues: json.stringList('acr_values'),
      maxAge: maxAge == null ? null : Duration(seconds: maxAge),
      redirectUri: redirectUri == null ? null : Uri.parse(redirectUri),
      state: json.optionalString('state'),
      prompt: json.optionalString('prompt'),
      uiLocales: json.stringList('ui_locales'),
      idTokenHint: json.optionalString('id_token_hint'),
      organization: json.optionalString('organization'),
    );
  }

  /// Space-separated scope list.
  final String scope;

  /// S256 challenge; this profile requires it on every authorization.
  final String codeChallenge;

  /// Echoed in the ID token (OpenID Connect Core §3.1.2.1).
  final String nonce;

  /// Step-up requirements (RFC 9470 §4).
  final List<String> acrValues;
  final Duration? maxAge;

  /// Used only if the server converts this request into a browser flow
  /// (`redirect_to_web` with `request_uri`).
  final Uri? redirectUri;

  /// Returned on the browser redirect, see [redirectUri].
  final String? state;

  /// `create` for sign-up (OpenID Connect Prompt Create 1.0).
  final String? prompt;
  final List<String> uiLocales;

  /// Identifies the user when a step-up has no `auth_session`
  /// (OpenID Connect Core §3.1.2.1).
  final String? idTokenHint;

  /// The organization the session starts in (`doc/server-contract.md`
  /// §17); `null` lets the server pick the user's only one, or none.
  final String? organization;

  Map<String, String> toFormFields() => <String, String>{
    'scope': scope,
    'code_challenge': codeChallenge,
    'code_challenge_method': PkcePair.method,
    'nonce': nonce,
    if (acrValues.isNotEmpty) 'acr_values': acrValues.join(' '),
    'max_age': ?maxAge?.inSeconds.toString(),
    'redirect_uri': ?redirectUri?.toString(),
    'state': ?state,
    'prompt': ?prompt,
    if (uiLocales.isNotEmpty) 'ui_locales': uiLocales.join(' '),
    'id_token_hint': ?idTokenHint,
    'organization': ?organization,
  };

  ChallengeAuthorizationParameters copyWith({
    String? scope,
    String? codeChallenge,
    String? nonce,
    List<String>? acrValues,
    Duration? maxAge,
    Uri? redirectUri,
    String? state,
    String? prompt,
    List<String>? uiLocales,
    String? idTokenHint,
    String? organization,
  }) => ChallengeAuthorizationParameters(
    scope: scope ?? this.scope,
    codeChallenge: codeChallenge ?? this.codeChallenge,
    nonce: nonce ?? this.nonce,
    acrValues: acrValues ?? this.acrValues,
    maxAge: maxAge ?? this.maxAge,
    redirectUri: redirectUri ?? this.redirectUri,
    state: state ?? this.state,
    prompt: prompt ?? this.prompt,
    uiLocales: uiLocales ?? this.uiLocales,
    idTokenHint: idTokenHint ?? this.idTokenHint,
    organization: organization ?? this.organization,
  );

  Map<String, Object?> toJson() => <String, Object?>{
    'scope': scope,
    'code_challenge': codeChallenge,
    'nonce': nonce,
    'acr_values': acrValues,
    'max_age': ?maxAge?.inSeconds,
    'redirect_uri': ?redirectUri?.toString(),
    'state': ?state,
    'prompt': ?prompt,
    'ui_locales': uiLocales,
    'id_token_hint': ?idTokenHint,
    'organization': ?organization,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ChallengeAuthorizationParameters &&
          scope == other.scope &&
          codeChallenge == other.codeChallenge &&
          nonce == other.nonce &&
          acrValues.hasSameValues(other.acrValues) &&
          maxAge == other.maxAge &&
          redirectUri == other.redirectUri &&
          state == other.state &&
          prompt == other.prompt &&
          uiLocales.hasSameValues(other.uiLocales) &&
          idTokenHint == other.idTokenHint &&
          organization == other.organization;

  @override
  int get hashCode => Object.hash(
    scope,
    codeChallenge,
    nonce,
    acrValues.valuesHash,
    maxAge,
    redirectUri,
    state,
    prompt,
    uiLocales.valuesHash,
    idTokenHint,
    organization,
  );
}
