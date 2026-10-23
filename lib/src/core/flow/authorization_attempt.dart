import 'package:loginflow_auth/src/core/crypto/pkce_pair.dart';
import 'package:loginflow_auth/src/core/crypto/secure_random_source.dart';
import 'package:loginflow_auth/src/core/json/list_equality.dart';
import 'package:loginflow_auth/src/core/protocol/challenge/challenge_authorization_parameters.dart';
import 'package:loginflow_auth/src/core/state/challenge_purpose.dart';

/// One authorization in progress: the PKCE pair, `nonce` and `state` that
/// bind every request of the attempt, plus the current `auth_session`.
///
/// Internal flow state; never persisted, so no `toJson`/`fromJson`.
class AuthorizationAttempt {
  const AuthorizationAttempt({
    required this.purpose,
    required this.pkce,
    required this.nonce,
    required this.state,
    this.authSession,
    this.isAuthorizationSent = false,
    this.loginHint,
    this.prompt,
    this.acrValues = const <String>[],
    this.maxAge,
    this.idTokenHint,
    this.organization,
  });

  factory AuthorizationAttempt.start({
    required ChallengePurpose purpose,
    required SecureRandomSource randomSource,
    String? authSession,
    String? loginHint,
    String? prompt,
    List<String> acrValues = const <String>[],
    Duration? maxAge,
    String? idTokenHint,
    String? organization,
  }) => AuthorizationAttempt(
    purpose: purpose,
    pkce: PkcePair.generate(randomSource),
    nonce: randomSource.nextOpaqueToken(),
    state: randomSource.nextOpaqueToken(),
    authSession: authSession,
    loginHint: loginHint,
    prompt: prompt,
    acrValues: acrValues,
    maxAge: maxAge,
    idTokenHint: idTokenHint,
    organization: organization,
  );

  final ChallengePurpose purpose;
  final PkcePair pkce;
  final String nonce;
  final String state;
  final String? authSession;

  /// Whether the authorization parameters already reached the server; after
  /// that, requests only carry `auth_session` and step input.
  final bool isAuthorizationSent;
  final String? loginHint;
  final String? prompt;
  final List<String> acrValues;
  final Duration? maxAge;

  /// Identifies the user of a step-up that has no `auth_session`
  /// (OpenID Connect Core §3.1.2.1 `id_token_hint`).
  final String? idTokenHint;

  /// The organization the session starts in (`doc/server-contract.md`
  /// §17), sent with the opening request.
  final String? organization;

  ChallengeAuthorizationParameters toParameters({
    required String scope,
    required Uri? redirectUri,
    required List<String> uiLocales,
  }) => ChallengeAuthorizationParameters(
    scope: scope,
    codeChallenge: pkce.codeChallenge,
    nonce: nonce,
    acrValues: acrValues,
    maxAge: maxAge,
    redirectUri: redirectUri,
    state: redirectUri == null ? null : state,
    prompt: prompt,
    uiLocales: uiLocales,
    idTokenHint: idTokenHint,
    organization: organization,
  );

  AuthorizationAttempt copyWith({
    ChallengePurpose? purpose,
    PkcePair? pkce,
    String? nonce,
    String? state,
    String? authSession,
    bool? isAuthorizationSent,
    String? loginHint,
    String? prompt,
    List<String>? acrValues,
    Duration? maxAge,
    String? idTokenHint,
    String? organization,
  }) => AuthorizationAttempt(
    purpose: purpose ?? this.purpose,
    pkce: pkce ?? this.pkce,
    nonce: nonce ?? this.nonce,
    state: state ?? this.state,
    authSession: authSession ?? this.authSession,
    isAuthorizationSent: isAuthorizationSent ?? this.isAuthorizationSent,
    loginHint: loginHint ?? this.loginHint,
    prompt: prompt ?? this.prompt,
    acrValues: acrValues ?? this.acrValues,
    maxAge: maxAge ?? this.maxAge,
    idTokenHint: idTokenHint ?? this.idTokenHint,
    organization: organization ?? this.organization,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AuthorizationAttempt &&
          purpose == other.purpose &&
          pkce == other.pkce &&
          nonce == other.nonce &&
          state == other.state &&
          authSession == other.authSession &&
          isAuthorizationSent == other.isAuthorizationSent &&
          loginHint == other.loginHint &&
          prompt == other.prompt &&
          acrValues.hasSameValues(other.acrValues) &&
          maxAge == other.maxAge &&
          idTokenHint == other.idTokenHint &&
          organization == other.organization;

  @override
  int get hashCode => Object.hash(
    purpose,
    pkce,
    nonce,
    state,
    authSession,
    isAuthorizationSent,
    loginHint,
    prompt,
    acrValues.valuesHash,
    maxAge,
    idTokenHint,
    organization,
  );

  @override
  String toString() => 'AuthorizationAttempt(purpose: ${purpose.name})';
}
