import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:loginflow_auth/src/core/crypto/base64_url_encoding.dart';
import 'package:loginflow_auth/src/core/crypto/pkce_pair.dart';
import 'package:loginflow_auth/src/core/crypto/sha256_hashing.dart';
import 'package:loginflow_auth/src/core/dpop/dpop_proof_factory.dart'
    show AccessTokenHash;
import 'package:loginflow_auth/src/core/jose/compact_jws.dart';
import 'package:loginflow_auth/src/core/jose/json_web_key.dart';
import 'package:loginflow_auth/src/core/jose/jws_header.dart';
import 'package:loginflow_auth/src/core/jose/jws_signature_verifier.dart';
import 'package:loginflow_auth/src/core/protocol/login_options/passkey_mode.dart';

import 'test_signing_keys.dart';

/// How the next ID tokens are corrupted, to exercise client validation.
enum IdTokenTampering {
  none,
  wrongIssuer,
  wrongAudience,
  wrongNonce,
  badSignature,
  expired,
  algorithmNone,
  accessTokenType,
}

/// A user known to the fake server: an account (email, password), or an
/// access-code subject of a tenant backend (`ext_sub`, `subject_kind`,
/// `ext_profile`; no personal data, `doc/server-contract.md` §16).
class FakeUser {
  const FakeUser({
    required this.subject,
    this.email,
    this.password,
    this.name,
    this.isTotpEnabled = false,
    this.hasUnusedRecoveryCodes = true,
    this.externalSubject,
    this.subjectKind,
    this.subjectProfile,
  });

  final String subject;
  final String? email;
  final String? password;
  final String? name;
  final bool isTotpEnabled;

  /// Whether the account still holds an unused recovery code: the real
  /// server offers `recovery_code` on a second-factor step only then
  /// (`RecoveryCodeRepository::has_unused_codes`). `true` by default, like
  /// an account that kept the codes it got when it enrolled TOTP.
  final bool hasUnusedRecoveryCodes;
  final String? externalSubject;
  final String? subjectKind;
  final String? subjectProfile;

  FakeUser copyWith({String? email, bool? isTotpEnabled}) => FakeUser(
    subject: subject,
    email: email ?? this.email,
    password: password,
    name: name,
    isTotpEnabled: isTotpEnabled ?? this.isTotpEnabled,
    hasUnusedRecoveryCodes: hasUnusedRecoveryCodes,
    externalSubject: externalSubject,
    subjectKind: subjectKind,
    subjectProfile: subjectProfile,
  );
}

/// A code the fake LoginFlow emailed for an email change, and where.
typedef FakeSentCode = ({String address, String code});

/// An organization of the application where a [FakeUser] has an active
/// assignment, with the permissions it gives per API audience
/// (`doc/server-contract.md` §17).
class FakeOrganization {
  const FakeOrganization({
    required this.id,
    required this.name,
    this.kind = 'regular',
    this.externalId,
    this.permissions = const <String, List<String>>{},
  });

  final String id;
  final String name;

  /// `root` or `regular`, as the real server sends it.
  final String kind;
  final String? externalId;

  /// The effective permissions in this organization, keyed by API audience.
  final Map<String, List<String>> permissions;

  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'external_id': externalId,
    'name': name,
    'kind': kind,
  };
}

/// An organization as the members API sees it (`doc/server-contract.md`
/// §18), its JSON exactly as `loginflow_api` serializes it.
class FakeMembersOrganization {
  const FakeMembersOrganization({
    required this.id,
    required this.name,
    this.kind = 'regular',
    this.grantableRoles = const <Map<String, Object?>>[],
    this.members = const <Map<String, Object?>>[],
  });

  final String id;
  final String name;
  final String kind;

  /// `GrantableRole` objects: what the signed-in user may grant here.
  final List<Map<String, Object?>> grantableRoles;

  /// `OrganizationMember` objects.
  final List<Map<String, Object?>> members;

  Map<String, Object?> get summary => <String, Object?>{
    'id': id,
    'name': name,
    'kind': kind,
  };
}

/// One HTTP exchange, independent of the transport.
class FakeHttpRequest {
  const FakeHttpRequest({
    required this.method,
    required this.uri,
    required this.headers,
    required this.body,
  });

  final String method;
  final Uri uri;

  /// Lower-case header names.
  final Map<String, String> headers;
  final String body;
}

/// The response being built for a [FakeHttpRequest].
class FakeHttpResponse {
  int statusCode = 200;
  final Map<String, String> headers = <String, String>{};
  String body = '';
}

/// A LoginFlow authorization server that implements `doc/server-contract.md`.
///
/// [start] serves it on a real loopback `HttpServer` (core tests exercise the
/// actual wire); [inMemory] serves the same logic through an
/// `http.MockClient`, for widget tests where sockets are blocked. Every
/// request is recorded so tests assert on what was sent.
class FakeLoginFlowServer {
  FakeLoginFlowServer._(this.keys, this.issuer, this._server);

  factory FakeLoginFlowServer.inMemory(TestSigningKeys keys) =>
      FakeLoginFlowServer._(keys, Uri.parse('https://login.fake.test'), null);

  static Future<FakeLoginFlowServer> start(TestSigningKeys keys) async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final fake = FakeLoginFlowServer._(
      keys,
      Uri.parse('http://127.0.0.1:${server.port}'),
      server,
    );
    server.listen(fake._serve);
    return fake;
  }

  static const String emailOtpCode = '424242';
  static const String magicLinkToken = 'magic-link-token-under-test';
  static const String totpCode = '123456';
  static const String recoveryCode = 'RECOVERY-0001';
  static const String passkeyCredentialId = 'credential-ana-0001';
  static const String temporaryAccessPassCode = 'TAP-0001';

  /// A valid, normalized access code (`doc/server-contract.md` §16).
  static const String accessCode = 'K7M2Q9PX';

  /// Which account owns each enrolled passkey — resolved from the
  /// assertion's own credential id on a discoverable (no `login_hint`)
  /// sign-in, the same way `WebauthnRepository::
  /// find_credential_by_rp_and_credential_id` does on the real server.
  final Map<String, String> passkeyCredentialOwners = <String, String>{
    passkeyCredentialId: 'ana@example.com',
  };
  static const String googleWebClientId = 'google-web-client.apps.example';
  static const String companyId = 'company-acme';

  /// The `app` claim of every access token: the client's application.
  static const String applicationId = 'APP-FAKE000001';

  /// Two independent APIs of that application, by audience (RFC 8707
  /// `resource`, `doc/server-contract.md` §17).
  static const String routesApi = 'API-ROUTES0001';
  static const String reportsApi = 'API-REPORTS001';

  /// `MAX_TOKEN_PERMISSIONS` / `MAX_PERMISSIONS_CLAIM_BYTES` of the real
  /// token issuer: beyond either, the token carries
  /// `permissions_overage: true` and no `permissions`.
  static const int maxTokenPermissions = 150;
  static const int maxPermissionsClaimBytes = 4096;

  /// The APIs each client may ask tokens for (`oauth_client_apis`). Without
  /// `resource`, a client with exactly one gets that API's token; with
  /// zero or several, LoginFlow's own token (`aud` = issuer, no
  /// `permissions`).
  final Map<String, Set<String>> clientApis = <String, Set<String>>{
    'app-one': <String>{routesApi, reportsApi},
    'app-two': <String>{routesApi},
  };

  /// The organizations each subject has an active assignment in. Empty by
  /// default: no organization is active and every token lists no
  /// permission.
  final Map<String, List<FakeOrganization>> organizationsBySubject =
      <String, List<FakeOrganization>>{};

  final HttpServer? _server;
  final TestSigningKeys keys;

  /// The issuer identifier.
  final Uri issuer;
  final Random _random = Random.secure();

  final Map<String, FakeUser> users = <String, FakeUser>{
    'ana@example.com': const FakeUser(
      subject: 'cu_ana',
      email: 'ana@example.com',
      password: 'correct-horse',
      name: 'Ana Ruiz',
    ),
    'tomas@example.com': const FakeUser(
      subject: 'cu_tomas',
      email: 'tomas@example.com',
      password: 'battery-staple',
      name: 'Tomás Gil',
      isTotpEnabled: true,
    ),
  };

  /// Active access codes, keyed by normalized code. Single use: a redeemed
  /// code is removed, exactly like the real server hard-deletes the row.
  final Map<String, FakeUser> accessCodes = <String, FakeUser>{
    accessCode: const FakeUser(
      subject: 'as_driver_7',
      externalSubject: 'driver:7',
      subjectKind: 'person',
      subjectProfile: 'Driver',
    ),
  };

  /// The access-code subjects that redeemed a code, by subject id: a
  /// passkey one of them enrolls signs that subject in again.
  final Map<String, FakeUser> _accessSubjects = <String, FakeUser>{};

  /// `false` plays a server that predates access codes: the `access_code`
  /// method is ignored and the usual next step is answered.
  bool implementsAccessCodes = true;

  /// The application's access-code setting (disabled answers
  /// `access_codes_disabled`).
  bool areAccessCodesEnabled = true;

  /// `true` answers every access-code redemption with the contract's
  /// `429 slow_down` (`Retry-After: 900`), like the per-application failure
  /// threshold.
  bool isAccessCodeThrottled = false;

  /// `false` plays a server whose discovery document has no
  /// `authorization_challenge_endpoint`.
  bool advertisesChallengeEndpoint = true;

  /// The challenge error replies of the real API, copied verbatim from the
  /// wire contract generated by serializing its Rust types
  /// (`access_codes.challenge_errors`): `{status, retry_after, body}` keyed
  /// by `error`.
  static final Map<String, Object?> accessCodeErrorReplies = jsonDecode(
    File('test/fixtures/access_code_challenge_errors.json').readAsStringSync(),
  ) as Map<String, Object?>;

  /// Clients allowed to share one Native SSO group.
  final Set<String> ssoGroup = <String>{'app-one', 'app-two'};

  List<String> loginMethods = <String>[
    'password',
    'email_otp',
    'google',
    'microsoft',
  ];
  bool isSelfSignUpEnabled = true;

  /// `select_method`'s candidates in the order the real server lists them
  /// (`PRIMARY_METHODS`,
  /// `loginflow_api/src/features/login_engine/service/challenge_service.rs:1694-1701`).
  static const Map<String, String> _primaryStepMethods = <String, String>{
    'password': 'password',
    'email_otp': 'email_otp',
    'google': 'google',
    'microsoft': 'microsoft',
    'apple': 'apple',
    'facebook': 'facebook',
  };

  /// A `password` step's candidates: a passkey as the first factor
  /// (`webauthn_identify`) is allowed by `passkey` (`PASSWORD_STEP_METHODS`,
  /// `loginflow_api/src/features/login_engine/service/challenge_service.rs:1706-1707`).
  static const Map<String, String> _passwordStepMethods = <String, String>{
    'password': 'password',
    'email_otp': 'email_otp',
    'webauthn_identify': 'passkey',
  };

  bool isPasswordResetEnabled = true;

  /// The company's passkey policy (`GET /oauth2/login-options`,
  /// `doc/server-contract.md` §4): `true` + [passkeyMode] by default, so
  /// tests that do not care about this keep seeing the passkey button they
  /// did before the server started publishing it.
  bool hasPasskey = true;
  PasskeyMode? passkeyMode = PasskeyMode.passwordless;
  String? googleServerClientId = '1234567890-fake.apps.googleusercontent.com';
  String? facebookAppId = '1234567890123456';
  bool isNativeSsoSupported = true;
  String idTokenAlgorithm = 'RS256';
  IdTokenTampering tampering = IdTokenTampering.none;

  /// The next refresh answers `insufficient_authorization` (first-party-apps
  /// §6.2) instead of tokens.
  bool requiresReauthenticationOnRefresh = false;

  /// When set, a refresh response is computed and then held until it
  /// completes, to reproduce a refresh that finishes late.
  Completer<void>? refreshResponseGate;

  /// Holds a computed authorization-code token response until completed.
  Completer<void>? codeResponseGate;

  /// Holds a computed challenge response until completed.
  Completer<void>? challengeResponseGate;

  /// The next refresh answers `invalid_grant`.
  bool rejectNextRefresh = false;

  /// Refresh responses leave out the ID token (a server bug the client
  /// must survive without pairing a new device secret with an old token).
  bool omitsIdTokenOnRefresh = false;

  /// The refresh token of the last token response.
  String? lastIssuedRefreshToken;

  /// The login options endpoint answers 503 while this is true.
  bool isLoginOptionsDown = false;

  /// The next challenge request answers 429 with this `Retry-After`.
  Duration? rateLimitNextChallenge;

  /// Simulated hosted-login browser session for `prompt=none`.
  bool hasBrowserSession = false;

  /// When true, every challenge/token/resource request must carry a valid
  /// DPoP proof (RFC 9449), as the LoginFlow profile requires for `native` +
  /// `first_party` clients (`doc/server-contract.md` §13).
  bool requiresDpop = false;

  /// The next DPoP-protected request answers `400 use_dpop_nonce` once, with
  /// this nonce in the `DPoP-Nonce` response header (RFC 9449 §8).
  String? nextDpopNonceChallenge;

  /// Every DPoP proof's public key thumbprint this server has accepted, in
  /// call order — tests assert the same key signed every proof of a flow.
  final List<String> acceptedDpopThumbprints = <String>[];

  final Set<String> _usedDpopJti = <String>{};

  /// The last nonce this server challenged with: once issued, every later
  /// proof must carry it (RFC 9449 §8).
  String? _requiredDpopNonce;

  final List<Map<String, String>> challengeRequests = <Map<String, String>>[];
  final List<Map<String, String>> tokenRequests = <Map<String, String>>[];
  final List<Map<String, String>> revocationRequests = <Map<String, String>>[];
  final List<String> deviceLogoutTokens = <String>[];
  final List<String> globalLogoutTokens = <String>[];
  final List<Uri> endSessionRequests = <Uri>[];
  final List<String> sentEmailOtps = <String>[];
  final List<String> sentMagicLinks = <String>[];

  final Map<String, _ChallengeSession> _sessions =
      <String, _ChallengeSession>{};
  final Map<String, String> _pushedRequests = <String, String>{};
  final Map<String, _IssuedCode> _codes = <String, _IssuedCode>{};
  final Map<String, _RefreshRecord> _refreshTokens = <String, _RefreshRecord>{};
  final Set<String> _revokedFamilies = <String>{};

  /// The active organization of each refresh family
  /// (`oauth_refresh_families.organization_id`).
  final Map<String, String?> _familyOrganizations = <String, String?>{};
  final Map<String, _DeviceSession> _deviceSessions =
      <String, _DeviceSession>{};
  final Map<String, String> _deviceSecrets = <String, String>{};
  final Map<String, _AccessRecord> _accessTokens = <String, _AccessRecord>{};
  final Map<String, String> _idTokenDeviceSecretHash = <String, String>{};

  String get issuerText => issuer.toString();

  /// An HTTP client that reaches this server without sockets.
  http.Client get client => MockClient((request) async {
    final reply = await respond(
      FakeHttpRequest(
        method: request.method,
        uri: request.url,
        headers: <String, String>{
          for (final MapEntry(:key, :value) in request.headers.entries)
            key.toLowerCase(): value,
        },
        body: request.body,
      ),
    );
    return http.Response(reply.body, reply.statusCode, headers: reply.headers);
  });

  Future<void> close() async => _server?.close(force: true);

  Future<void> _serve(HttpRequest request) async {
    final headers = <String, String>{};
    request.headers.forEach((name, values) => headers[name] = values.join(','));
    final reply = await respond(
      FakeHttpRequest(
        method: request.method,
        uri: request.uri,
        headers: headers,
        body: await utf8.decoder.bind(request).join(),
      ),
    );
    request.response.statusCode = reply.statusCode;
    reply.headers.forEach(request.response.headers.set);
    request.response.write(reply.body);
    await request.response.close();
  }

  int get tokenRequestCount => tokenRequests.length;

  int refreshRequestCount() => tokenRequests
      .where((request) => request['grant_type'] == 'refresh_token')
      .length;

  /// Forgets every `auth_session`, as if they expired.
  void expireChallengeSessions() => _sessions.clear();

  /// Ends every device session, as a "sign out everywhere" from another
  /// device or an administrator does: every access token of them is
  /// refused from then on.
  void endEveryDeviceSession() {
    for (final session in _deviceSessions.values) {
      session.isActive = false;
    }
  }

  bool isDeviceSessionActive(String sid) =>
      _deviceSessions[sid]?.isActive ?? false;

  Map<String, Object?> get discovery => <String, Object?>{
    'issuer': issuerText,
    'authorization_endpoint': '$issuerText/oauth2/authorize',
    if (advertisesChallengeEndpoint)
      'authorization_challenge_endpoint':
          '$issuerText/oauth2/authorize-challenge',
    'token_endpoint': '$issuerText/oauth2/token',
    'jwks_uri': '$issuerText/oauth2/jwks',
    'revocation_endpoint': '$issuerText/oauth2/revoke',
    'end_session_endpoint': '$issuerText/oauth2/end-session',
    'loginflow_login_options_endpoint': '$issuerText/oauth2/login-options',
    'loginflow_device_logout_endpoint': '$issuerText/oauth2/device-logout',
    'loginflow_global_logout_endpoint': '$issuerText/oauth2/logout-everywhere',
    'organizations_endpoint': '$issuerText$organizationsPath',
    'response_types_supported': <String>['code'],
    'subject_types_supported': <String>['public'],
    'id_token_signing_alg_values_supported': <String>['RS256', 'ES256'],
    'code_challenge_methods_supported': <String>['S256'],
    'grant_types_supported': <String>[
      'authorization_code',
      'refresh_token',
      'client_credentials',
      'urn:ietf:params:oauth:grant-type:token-exchange',
    ],
    'token_endpoint_auth_methods_supported': <String>['none'],
    'native_sso_supported': isNativeSsoSupported,
    'authorization_response_iss_parameter_supported': true,
    'scopes_supported': <String>[
      'openid',
      'profile',
      'email',
      'offline_access',
      'device_sso',
    ],
  };

  /// Endpoints the LoginFlow profile requires a DPoP proof on: the
  /// challenge and token endpoints, and the two resource (Bearer/DPoP)
  /// logout endpoints (`doc/server-contract.md` §13).
  static const Set<String> _dpopProtectedPaths = <String>{
    '/oauth2/authorize-challenge',
    '/oauth2/token',
    '/oauth2/device-logout',
    '/oauth2/logout-everywhere',
    organizationsPath,
    userProfilePath,
  };

  /// The protected resources among [_dpopProtectedPaths]: authenticated
  /// by `jwt_middleware::authenticate_oauth_resource`, which answers every
  /// refusal as `401` + `WWW-Authenticate` and no body (RFC 6750 §3,
  /// RFC 9449 §7.1) — the two logout endpoints included.
  static const Set<String> _resourcePaths = <String>{
    '/oauth2/device-logout',
    '/oauth2/logout-everywhere',
    organizationsPath,
    userProfilePath,
  };

  /// `GET /oauth2/organizations` (`doc/server-contract.md` §17).
  static const String organizationsPath = '/oauth2/organizations';

  /// A DPoP/Bearer-protected resource of the `/v1/user` REST scope.
  static const String userProfilePath = '/v1/user/me';

  /// The passkey account-management REST surface
  /// (`doc/server-contract.md` §15): `data`/`meta` envelope on success,
  /// `error`/`meta` on failure — same `ApiResponse` shape as every other
  /// `/v1/user` resource.
  static const String passkeysCollectionPath = '/v1/user/passkeys';

  /// Enrolled passkeys, keyed by credential id, scoped to their owner's
  /// subject the same way `WebauthnRepository` scopes them to a company
  /// user.
  final Map<String, _EnrolledPasskey> _enrolledPasskeys =
      <String, _EnrolledPasskey>{};

  /// Device sessions (`sid`) whose authentication is older than the
  /// recent-auth window. `enroll/start` refuses their access tokens like the
  /// real gate does for an `auth_time` older than 300 s
  /// (`loginflow_api/src/shared/helper/recent_auth.rs:28` `is_stale`,
  /// answered by `recent_auth_required` at :40): `401`, the standard error
  /// envelope, and `WWW-Authenticate: Bearer
  /// error="insufficient_user_authentication", max_age=300` (:54). A
  /// refresh keeps its session's `auth_time`, so it stays stale; only a new
  /// authentication (a new `sid`) is recent again.
  final Set<String> _staleAuthentications = <String>{};

  /// When set, every `/v1/user/passkeys*` call answers `403` with this
  /// `error.code` in the standard envelope: the server's clean refusal of a
  /// passkey path that cannot serve the caller (`doc/server-contract.md`
  /// §15).
  String? passkeyAccountRefusal;

  /// Plays the 300 s recent-auth window passing for every authentication
  /// done so far; one done afterwards (a step-up) is recent.
  void expireRecentAuthentications() =>
      _staleAuthentications.addAll(_deviceSessions.keys);

  /// Handles one request; both transports end here.
  Future<FakeHttpResponse> respond(FakeHttpRequest request) async {
    final form = request.method == 'POST'
        ? Uri.splitQueryString(request.body)
        : null;
    final response = FakeHttpResponse();
    response.headers['cache-control'] = 'no-store';
    if (requiresDpop && _dpopProtectedPaths.contains(request.uri.path)) {
      final dpopError = _checkDpop(request, response);
      final isResource = _resourcePaths.contains(request.uri.path);
      if (dpopError != null && isResource) {
        // RFC 9449 §9: a resource answers 401 with the error in
        // `WWW-Authenticate`, not the token endpoint's 400 body.
        response
          ..statusCode = 401
          ..headers['www-authenticate'] = 'DPoP error="$dpopError"';
        return response;
      }
      if (dpopError != null) {
        _oauthError(response, 400, dpopError);
        return response;
      }
    }
    switch ((request.method, request.uri.path)) {
      case ('GET', '/.well-known/openid-configuration'):
        response.headers['cache-control'] = 'public, max-age=3600';
        _json(response, 200, discovery);
      case ('GET', '/oauth2/jwks'):
        response.headers['cache-control'] = 'public, max-age=21600';
        _json(response, 200, keys.jwks);
      case ('GET', '/oauth2/login-options') when isLoginOptionsDown:
        _oauthError(response, 503, 'temporarily_unavailable');
      case ('GET', '/oauth2/login-options'):
        _json(response, 200, <String, Object?>{
          'client_id': request.uri.queryParameters['client_id'],
          'login_methods': _allowedLoginMethods,
          'self_signup': isSelfSignUpEnabled,
          'password_reset': isPasswordResetEnabled,
          'passkey': hasPasskey,
          if (hasPasskey) 'passkey_mode': passkeyMode?.wireName,
          if (googleServerClientId != null)
            'google_server_client_id': googleServerClientId,
          if (facebookAppId != null) 'facebook_app_id': facebookAppId,
        });
      case ('POST', '/oauth2/authorize-challenge'):
        challengeRequests.add(form ?? <String, String>{});
        final retryAfter = rateLimitNextChallenge;
        rateLimitNextChallenge = null;
        if (retryAfter != null) {
          response.headers['retry-after'] = '${retryAfter.inSeconds}';
          _oauthError(response, 429, 'rate_limited');
        } else {
          _challenge(response, form ?? <String, String>{});
          await challengeResponseGate?.future;
        }
      case ('GET', '/oauth2/authorize'):
        _authorize(response, request.uri.queryParameters);
      case ('POST', '/oauth2/token'):
        tokenRequests.add(form ?? <String, String>{});
        _token(response, form ?? <String, String>{});
        if (form?['grant_type'] == 'authorization_code') {
          await codeResponseGate?.future;
        }
        if (form?['grant_type'] == 'refresh_token') {
          await refreshResponseGate?.future;
        }
      case ('POST', '/oauth2/revoke'):
        revocationRequests.add(form ?? <String, String>{});
        _revoke(response, form ?? <String, String>{});
      case ('POST', '/oauth2/device-logout'):
        _endSessions(request, response, everywhere: false);
      case ('POST', '/oauth2/logout-everywhere'):
        _endSessions(request, response, everywhere: true);
      case ('GET', userProfilePath):
        _userProfile(request, response);
      case ('GET', organizationsPath):
        _listOrganizations(request, response);
      case ('POST', '$passkeysCollectionPath/enroll/start'):
        _passkeysEnrollStart(request, response);
      case ('POST', '$passkeysCollectionPath/enroll/finish'):
        _passkeysEnrollFinish(request, response);
      case ('GET', passkeysCollectionPath):
        _passkeysList(request, response);
      case ('PATCH', final path)
          when path.startsWith('$passkeysCollectionPath/'):
        _passkeysRename(request, response, path.split('/').last);
      case ('DELETE', final path)
          when path.startsWith('$passkeysCollectionPath/'):
        _passkeysDelete(request, response, path.split('/').last);
      case (final method, final path)
          when path == membersPath || path.startsWith('$membersPath/'):
        _members(request, response, method, path.substring(membersPath.length));
      case (final method, final path) when path.startsWith('$totpPath/'):
        _totp(request, response, method, path.substring(totpPath.length));
      case (final method, final path)
          when path == emailChangePath || path.startsWith('$emailChangePath/'):
        _emailChange(
          request,
          response,
          method,
          path.substring(emailChangePath.length),
        );
      case ('GET', '/oauth2/end-session'):
        endSessionRequests.add(request.uri);
        hasBrowserSession = false;
        final query = request.uri.queryParameters;
        _redirect(
          response,
          Uri.parse(query['post_logout_redirect_uri'] ?? '').replace(
            queryParameters: <String, String>{'state': query['state'] ?? ''},
          ),
        );
      default:
        response.statusCode = 404;
    }
    return response;
  }

  void _challenge(FakeHttpResponse response, Map<String, String> form) {
    final clientId = form['client_id'];
    if (clientId == null || form['response_type'] != 'code') {
      return _oauthError(response, 400, 'invalid_request');
    }
    final sessionKey = form['auth_session'];
    final challenge = form['code_challenge'];
    final _ChallengeSession session;
    if (sessionKey == null) {
      session = _openSession(clientId);
    } else {
      final existing = _sessions[sessionKey];
      final isStepUpOpening = challenge != null;
      // A completed transaction keeps its `auth_session` only as a step-up
      // handle (`ChallengeService::open_step_up`): a step-up opening on an
      // open one, or a continuation of a completed one, names no live
      // transaction (`challenge_service.rs::subject_behind_auth_session`).
      if (existing == null || existing.isCompleted != isStepUpOpening) {
        return _oauthError(response, 400, 'invalid_session');
      }
      // The step-up opens a NEW transaction for the completed one's subject,
      // identifier locked, which answers the primary factor, never a code.
      session = isStepUpOpening
          ? (_openSession(clientId)
              ..email = existing.email
              ..isIdentifiedByHint = true)
          : existing;
    }
    if (sessionKey != null && challenge == null && !_carriesStep(form)) {
      // A continuation with no step field the server dispatches on
      // (`challenge_handler.rs::continue_with_step` answers `None`):
      // `method=password` or `method=totp` alone is not one.
      return _json(response, 400, <String, Object?>{
        'error': 'invalid_request',
        'error_description': 'No recognized step parameter in the request',
      });
    }
    if (challenge != null) {
      if (form['code_challenge_method'] != 'S256' ||
          !_isKnownOrganization(form['organization'])) {
        return _oauthError(response, 400, 'invalid_request');
      }
      session.openAuthorization(
        codeChallenge: challenge,
        nonce: form['nonce'],
        scope: form['scope'] ?? '',
        redirectUri: form['redirect_uri'],
        state: form['state'],
        acrValues: form['acr_values'],
        organization: form['organization'],
      );
    }
    if (session.codeChallenge == null) {
      return _oauthError(response, 400, 'invalid_request');
    }
    final loginHint = form['login_hint'];
    if (loginHint != null) {
      session.email = loginHint;
    }
    final idTokenHint = form['id_token_hint'];
    if (idTokenHint != null) {
      // Identifies the user only; never a primary factor.
      session
        ..email = _emailOfIdToken(idTokenHint)
        ..isPrimaryAuthenticated = false
        ..isIdentifiedByHint = true;
    }
    if (form['max_age'] != null) {
      // A step-up for a recent authentication (`LoginFlowAuth.stepUp` with
      // the gate's `max_age`): the real server never reuses an earlier
      // authentication for an opening request — `open()` starts every
      // transaction from `TxnState::start()`
      // (`loginflow_api/src/features/login_engine/service/challenge_service.rs:409`,
      // reached from `challenge_handler.rs:353-360`) — so the known user
      // is asked for a primary factor again.
      session
        ..isPrimaryAuthenticated = false
        ..isSecondFactorDone = false
        ..isIdentifiedByHint = true;
    }
    if (form['prompt'] == 'create' || form['intent'] == 'password_reset') {
      return _redirectToWeb(response, session);
    }
    if (form['method'] == 'access_code' && implementsAccessCodes) {
      return _redeemAccessCode(response, session, form['access_code']);
    }
    final provider = form['upstream_provider'];
    const nativeUpstreamProviders = <String>{'google', 'apple', 'facebook'};
    if (provider == 'microsoft' ||
        (nativeUpstreamProviders.contains(provider) &&
            form['upstream_flow'] == 'browser')) {
      return _redirectToWeb(response, session);
    }
    if (provider != null && nativeUpstreamProviders.contains(provider)) {
      final token = form['upstream_token'];
      if (token == null) {
        session.upstreamNonce = _token32();
        return _step(
          response,
          session,
          'upstream_token',
          upstream: <String, Object?>{
            'provider': provider,
            'nonce': session.upstreamNonce,
            'client_id': provider == 'google'
                ? googleWebClientId
                : '$provider-client.example',
          },
        );
      }
      // Facebook's classic (Android) access token carries no nonce, unlike
      // every other case here (Google always, Apple always, Facebook's
      // iOS Limited Login) — same as the real server's Facebook access
      // token validation path.
      final isNonceless = form['upstream_token_type'] == 'access_token';
      final parts = token.split(':');
      if (parts.length != 3 ||
          parts[0] != provider ||
          (!isNonceless && parts[1] != session.upstreamNonce)) {
        return _step(
          response,
          session,
          'upstream_token',
          stepError: 'invalid_credential',
        );
      }
      session.email = parts[2];
      session.isPrimaryAuthenticated = users.containsKey(parts[2]);
    }
    var user = users[session.email];
    final password = form['password'];
    if (password != null) {
      if (user == null || user.password != password) {
        return _step(
          response,
          session,
          'password',
          stepError: 'invalid_credential',
        );
      }
      session.isPrimaryAuthenticated = true;
    }
    if (form['method'] == 'email_otp' || form['resend'] == 'email_otp') {
      sentEmailOtps.add(session.email ?? '');
      return _step(response, session, 'email_otp');
    }
    if (form['method'] == 'magic_link') {
      // Contract: magic link — one request, one email carrying both the
      // OTP code and the link; the server still answers `next: email_otp`.
      sentEmailOtps.add(session.email ?? '');
      sentMagicLinks.add(session.email ?? '');
      return _step(response, session, 'email_otp');
    }
    final otp = form['email_otp'];
    if (otp != null) {
      if (user == null || otp != emailOtpCode) {
        return _step(
          response,
          session,
          'email_otp',
          stepError: 'invalid_credential',
        );
      }
      session.isPrimaryAuthenticated = true;
    }
    final magicLinkTokenPresented = form['magic_link_token'];
    if (magicLinkTokenPresented != null) {
      if (user == null || magicLinkTokenPresented != magicLinkToken) {
        return _step(
          response,
          session,
          'email_otp',
          stepError: 'invalid_credential',
        );
      }
      session.isPrimaryAuthenticated = true;
    }
    final totp = form['totp'];
    final recovery = form['recovery_code'];
    if (totp != null || recovery != null) {
      final isValid = totp == totpCode || recovery == recoveryCode;
      if (!isValid) {
        return _step(
          response,
          session,
          totp != null ? 'totp' : 'recovery_code',
          stepError: 'invalid_credential',
        );
      }
      session.isSecondFactorDone = true;
    }
    if (form['method'] == 'webauthn_identify') {
      // `webauthn-rs`'s `RequestChallengeResponse`, as the real server
      // sends it: the WebAuthn options under `publicKey`, plus `mediation:
      // conditional` on a discoverable (no `login_hint`) request
      // (`WebauthnService::start_discoverable_authentication`). A targeted
      // request lists the account's passkeys as `{id, type}` with NO
      // `transports`: the server asks for no attestation, so webauthn-rs never
      // stores them (loginflow_api webauthn_identify_flow.rs:158-163).
      final email = session.email;
      final allowCredentials = <Object?>[
        if (email != null)
          for (final MapEntry(:key, :value) in passkeyCredentialOwners.entries)
            if (value == email)
              <String, Object?>{'id': key, 'type': 'public-key'},
      ];
      return _step(
        response,
        session,
        'webauthn_assertion',
        options: <String, Object?>{
          'publicKey': <String, Object?>{
            'challenge': _token32(),
            'rpId': issuer.host,
            'userVerification': 'required',
            if (allowCredentials.isNotEmpty)
              'allowCredentials': allowCredentials,
          },
          if (session.email == null) 'mediation': 'conditional',
        },
      );
    }
    final webauthnAssertion = form['webauthn_assertion'];
    if (webauthnAssertion != null) {
      final decoded = jsonDecode(webauthnAssertion) as Map<String, Object?>;
      final owner = passkeyCredentialOwners[decoded['id']];
      final subjectOwner = _subjectOwning(decoded['id']);
      if (owner == null && subjectOwner == null) {
        // No fresh `options` on a failed assertion: like a rejected
        // upstream token, a WebAuthn challenge is single-use, so the
        // client restarts with a new `signInWithPasskey` identify call
        // rather than retrying this step blindly.
        return _step(
          response,
          session,
          'webauthn_assertion',
          stepError: 'invalid_credential',
        );
      }
      // Discoverable sign-in (no `login_hint`): the credential id itself
      // identifies the account, same as `find_credential_by_rp_and_
      // credential_id` on the real server. `user` was already read above
      // (before this leg resolved the account), so it is re-read here.
      // A credential an access-code subject enrolled yields that subject's
      // session, the same token shape as a code redemption
      // (`doc/server-contract.md` §16).
      if (subjectOwner != null) {
        user = subjectOwner;
      } else {
        session.email ??= owner;
        user = users[session.email];
      }
      // A valid assertion satisfies BOTH factors in the same step
      // (`doc/server-contract.md` passkeys section): a passkey is
      // phishing-resistant on its own.
      session.isPrimaryAuthenticated = true;
      session.isSecondFactorDone = true;
    }
    final temporaryAccessPass = form['temporary_access_pass'];
    if (temporaryAccessPass != null) {
      if (temporaryAccessPass != temporaryAccessPassCode) {
        return _step(
          response,
          session,
          'temporary_access_pass',
          stepError: 'invalid_credential',
        );
      }
      // Also satisfies both factors in one step, but never
      // phishing-resistant — a TAP is a shared secret, not a possession
      // proof.
      session.isPrimaryAuthenticated = true;
      session.isSecondFactorDone = true;
    }
    final hasStepInput = _carriesStep(form);
    if (!session.isPrimaryAuthenticated &&
        !hasStepInput &&
        !session.isIdentifiedByHint) {
      return _step(response, session, 'select_method');
    }
    if (!session.isPrimaryAuthenticated &&
        !hasStepInput &&
        !_allowedLoginMethods.contains('password')) {
      // A step-up opening whose client does not allow `password` answers
      // `select_method` (`StepUpOpening`,
      // `loginflow_api/src/features/login_engine/engine.rs:115-117`).
      return _step(response, session, 'select_method');
    }
    if (!session.isPrimaryAuthenticated || user == null) {
      // A step-up opening of a client that allows `password` says `next:
      // password` with the client's password step `methods`
      // (`_stepMethods`), and takes `method=email_otp` on that
      // `auth_session` (above).
      return _step(response, session, 'password');
    }
    final needsSecondFactor =
        user.isTotpEnabled || (session.acrValues?.contains('mfa') ?? false);
    if (needsSecondFactor && !session.isSecondFactorDone) {
      return _step(response, session, 'totp');
    }
    final code = _issueChallengeCode(session, user);
    _json(response, 200, <String, Object?>{'authorization_code': code});
  }

  /// A new transaction under a fresh `auth_session`.
  _ChallengeSession _openSession(String clientId) {
    final session = _ChallengeSession(key: _token32(), clientId: clientId);
    _sessions[session.key] = session;
    return session;
  }

  /// Whether [form] carries a step the real server dispatches on, by field
  /// presence (`challenge_handler.rs::continue_with_step`): `method` only
  /// counts for the methods that act on the server (`email_otp` sends the
  /// code, `magic_link` the link, `webauthn_identify` starts a ceremony).
  /// A value the user types (`password`, `totp`, ...) is its own field, so
  /// `method=password` or `method=totp` is no step at all.
  static bool _carriesStep(Map<String, String> form) =>
      _stepFields.any(form.containsKey) ||
      _serverMethods.contains(form['method']) ||
      form['intent'] == 'password_reset';

  static const List<String> _stepFields = <String>[
    'password',
    'totp',
    'recovery_code',
    'email_otp',
    'magic_link_token',
    'temporary_access_pass',
    'webauthn_assertion',
    'upstream_provider',
    'resend',
  ];

  static const Set<String> _serverMethods = <String>{
    'email_otp',
    'magic_link',
    'webauthn_identify',
  };

  /// One leg: an authorization code, or a generic error that never tells an
  /// unknown code from an expired or used one (`doc/server-contract.md`
  /// §16).
  void _redeemAccessCode(
    FakeHttpResponse response,
    _ChallengeSession session,
    String? code,
  ) {
    if (isAccessCodeThrottled) {
      return _accessCodeError(response, 'slow_down');
    }
    if (!areAccessCodesEnabled) {
      return _accessCodeError(response, 'access_codes_disabled');
    }
    if (!_allowedLoginMethods.contains('access_code')) {
      // A client whose login methods lack `access_code` never redeems one
      // (`doc/server-contract.md` §16).
      return _oauthError(response, 400, 'unauthorized_client');
    }
    final subject = accessCodes.remove(code);
    if (subject == null) {
      return _accessCodeError(response, 'invalid_grant');
    }
    _accessSubjects[subject.subject] = subject;
    // Redeemed outside the login transaction: the code carries no
    // `redirect_uri` and no organization
    // (`access_code_redemption_service.rs`, `IssueCodeParams`).
    final issued = _issueCode(
      session,
      subject,
      redirectUri: null,
      organization: null,
    );
    session.isCompleted = true;
    _json(response, 200, <String, Object?>{'authorization_code': issued});
  }

  /// Deletes every passkey [subject] enrolled, as the server does when its
  /// backend issues a new code with `revoke_existing_sessions`, revokes or
  /// deletes the subject.
  void deletePasskeysOf(String subject) =>
      _enrolledPasskeys.removeWhere((_, passkey) => passkey.owner == subject);

  /// The access-code subject that enrolled the passkey [credentialId]
  /// through the account API, if any.
  FakeUser? _subjectOwning(Object? credentialId) {
    final owner = _enrolledPasskeys[credentialId]?.owner;
    return owner == null ? null : _accessSubjects[owner];
  }

  /// The exact reply of the real API for [error] ([accessCodeErrorReplies]).
  void _accessCodeError(FakeHttpResponse response, String error) {
    final reply = accessCodeErrorReplies[error]! as Map<String, Object?>;
    _json(
      response,
      reply['status']! as int,
      reply['body']! as Map<String, Object?>,
    );
    if (reply['retry_after'] case final String seconds) {
      response.headers['retry-after'] = seconds;
    }
  }

  void _authorize(FakeHttpResponse response, Map<String, String> query) {
    final requestUri = query['request_uri'];
    if (requestUri != null) {
      final session = _sessions[_pushedRequests.remove(requestUri)];
      final redirect = session?.redirectUri;
      if (session == null || redirect == null) {
        response.statusCode = 400;
        return;
      }
      final user = users[session.email] ?? users['ana@example.com']!;
      session.email = user.email;
      hasBrowserSession = true;
      final code = _issueCode(
        session,
        user,
        redirectUri: redirect,
        organization: session.organization,
      );
      return _redirect(
        response,
        Uri.parse(redirect).replace(
          queryParameters: <String, String>{
            'code': code,
            'state': session.state ?? '',
            'iss': issuerText,
          },
        ),
      );
    }
    final redirect = query['redirect_uri'];
    if (redirect == null ||
        query['response_type'] != 'code' ||
        query['code_challenge_method'] != 'S256' ||
        !_isKnownOrganization(query['organization'])) {
      response.statusCode = 400;
      return;
    }
    final callback = Uri.parse(redirect);
    if (query['prompt'] == 'none' && !hasBrowserSession) {
      return _redirect(
        response,
        callback.replace(
          queryParameters: <String, String>{
            'error': 'login_required',
            'state': query['state'] ?? '',
            'iss': issuerText,
          },
        ),
      );
    }
    hasBrowserSession = true;
    final session =
        _ChallengeSession(key: _token32(), clientId: query['client_id'] ?? '')
          ..openAuthorization(
            codeChallenge: query['code_challenge'] ?? '',
            nonce: query['nonce'],
            scope: query['scope'] ?? '',
            redirectUri: redirect,
            state: query['state'],
            acrValues: null,
            organization: query['organization'],
          )
          ..email = 'ana@example.com';
    final code = _issueCode(
      session,
      users['ana@example.com']!,
      redirectUri: redirect,
      organization: session.organization,
    );
    _redirect(
      response,
      callback.replace(
        queryParameters: <String, String>{
          'code': code,
          'state': query['state'] ?? '',
          'iss': issuerText,
        },
      ),
    );
  }

  void _token(FakeHttpResponse response, Map<String, String> form) {
    final clientId = form['client_id'];
    if (clientId == null) {
      return _oauthError(response, 401, 'invalid_client');
    }
    final resource = form['resource'];
    // `resource=<issuer>` (LoginFlow's own token) is valid for every sign-in
    // client, whatever its APIs (`doc/server-contract.md` §18).
    if (resource != null &&
        resource != issuerText &&
        !(clientApis[clientId] ?? const <String>{}).contains(resource)) {
      // RFC 8707 §2: the API is not one this client may ask tokens for.
      return _oauthError(response, 400, 'invalid_target');
    }
    switch (form['grant_type']) {
      case 'authorization_code':
        _redeemCode(response, form, clientId);
      case 'refresh_token':
        _refresh(response, form, clientId);
      case 'urn:ietf:params:oauth:grant-type:token-exchange':
        _exchange(response, form, clientId);
      default:
        _oauthError(response, 400, 'unsupported_grant_type');
    }
  }

  void _redeemCode(
    FakeHttpResponse response,
    Map<String, String> form,
    String clientId,
  ) {
    final issued = _codes.remove(form['code']);
    final verifier = form['code_verifier'];
    if (issued == null ||
        issued.clientId != clientId ||
        verifier == null ||
        PkcePair.challengeFor(verifier) != issued.codeChallenge ||
        issued.redirectUri != form['redirect_uri']) {
      return _oauthError(response, 400, 'invalid_grant');
    }
    final organization = _resolveOrganization(
      issued.user,
      requested: issued.organization,
    );
    if (organization.isUnavailable) {
      return _oauthError(response, 400, 'invalid_grant');
    }
    final sid = 'sid_${_token32()}';
    _deviceSessions[sid] = _DeviceSession(
      subject: issued.user.subject,
      isStrong: issued.isStrong,
    );
    final familyId = _token32();
    _familyOrganizations[familyId] = organization.active?.id;
    _issueTokens(
      response,
      clientId: clientId,
      user: issued.user,
      scope: issued.scope,
      sid: sid,
      nonce: issued.nonce,
      familyId: familyId,
      isRefresh: false,
      isDeviceSecretNeeded: true,
      organization: organization.active,
      resource: form['resource'],
    );
  }

  void _refresh(
    FakeHttpResponse response,
    Map<String, String> form,
    String clientId,
  ) {
    if (rejectNextRefresh) {
      rejectNextRefresh = false;
      return _oauthError(response, 400, 'invalid_grant');
    }
    final record = _refreshTokens[form['refresh_token']];
    if (record == null || record.clientId != clientId) {
      return _oauthError(response, 400, 'invalid_grant');
    }
    if (record.isUsed) {
      _revokedFamilies.add(record.familyId);
      return _oauthError(response, 400, 'invalid_grant');
    }
    if (_revokedFamilies.contains(record.familyId) ||
        !isDeviceSessionActive(record.sid)) {
      return _oauthError(response, 400, 'invalid_grant');
    }
    final requested = form['organization'];
    final organization = _resolveOrganization(
      record.user,
      requested: requested ?? _familyOrganizations[record.familyId],
    );
    if (organization.isUnavailable && requested != null) {
      // An explicit switch to an organization the user cannot work in:
      // refused without revoking or rotating anything.
      return _oauthError(response, 400, 'invalid_grant');
    }
    record.isUsed = true;
    _familyOrganizations[record.familyId] = organization.active?.id;
    if (requiresReauthenticationOnRefresh) {
      requiresReauthenticationOnRefresh = false;
      final session = _ChallengeSession(key: _token32(), clientId: clientId)
        ..email = record.user.email;
      _sessions[session.key] = session;
      return _json(response, 403, <String, Object?>{
        'error': 'insufficient_authorization',
        'auth_session': session.key,
        'next': 'email_otp',
      });
    }
    // Like the real issuer, the ID token's profile claims are read from the
    // profile at every rotation: a changed email shows on the next refresh.
    _issueTokens(
      response,
      clientId: clientId,
      user: _userBySubject(record.user.subject) ?? record.user,
      scope: record.scope,
      sid: record.sid,
      nonce: null,
      familyId: record.familyId,
      isRefresh: true,
      isDeviceSecretNeeded: !_deviceSecrets.containsKey(form['device_secret']),
      organization: organization.active,
      resource: form['resource'],
    );
  }

  void _exchange(
    FakeHttpResponse response,
    Map<String, String> form,
    String clientId,
  ) {
    final subjectToken = form['subject_token'] ?? '';
    final deviceSecret = form['actor_token'] ?? '';
    final sid = _deviceSecrets[deviceSecret];
    final isWellFormed =
        form['audience'] == issuerText &&
        form['subject_token_type'] ==
            'urn:ietf:params:oauth:token-type:id_token' &&
        form['actor_token_type'] ==
            'urn:openid:params:token-type:device-secret' &&
        (form['scope'] ?? '').split(' ').contains('openid');
    if (!isWellFormed) {
      return _oauthError(response, 400, 'invalid_request');
    }
    final dsHash = _idTokenDeviceSecretHash[subjectToken];
    if (sid == null ||
        !isDeviceSessionActive(sid) ||
        dsHash != _deviceSecretHash(deviceSecret) ||
        !ssoGroup.contains(clientId)) {
      return _oauthError(response, 400, 'invalid_grant');
    }
    final subject = _deviceSessions[sid]!.subject;
    final user = users.values.firstWhere((user) => user.subject == subject);
    final organization = _resolveOrganization(user, requested: null);
    final familyId = _token32();
    _familyOrganizations[familyId] = organization.active?.id;
    _issueTokens(
      response,
      clientId: clientId,
      user: user,
      scope: form['scope'] ?? '',
      sid: sid,
      nonce: null,
      familyId: familyId,
      isRefresh: false,
      isDeviceSecretNeeded: false,
      issuedTokenType: 'urn:ietf:params:oauth:token-type:access_token',
      organization: organization.active,
      resource: form['resource'],
    );
  }

  void _issueTokens(
    FakeHttpResponse response, {
    required String clientId,
    required FakeUser user,
    required String scope,
    required String sid,
    required String? nonce,
    required String familyId,
    required bool isRefresh,
    required bool isDeviceSecretNeeded,
    required FakeOrganization? organization,
    required String? resource,
    String? issuedTokenType,
  }) {
    final accessToken = _accessToken(
      clientId: clientId,
      user: user,
      sid: sid,
      scope: scope,
      organization: organization,
      resource: resource,
    );
    final refreshToken = 'rt_${_token32()}';
    lastIssuedRefreshToken = refreshToken;
    _accessTokens[accessToken] = _AccessRecord(
      subject: user.subject,
      sid: sid,
      organizationId: organization?.id,
      audience: CompactJws.parse(accessToken).data.claims['aud']! as String,
    );
    _refreshTokens[refreshToken] = _RefreshRecord(
      familyId: familyId,
      clientId: clientId,
      user: user,
      scope: scope,
      sid: sid,
    );
    final isDeviceSso =
        isDeviceSecretNeeded &&
        scope.split(' ').contains('device_sso') &&
        ssoGroup.contains(clientId);
    final deviceSecret = isDeviceSso ? 'ds_${_token32()}' : null;
    if (deviceSecret != null) {
      _deviceSecrets[deviceSecret] = sid;
    }
    final idToken = _idToken(
      clientId: clientId,
      user: user,
      sid: sid,
      nonce: nonce,
      deviceSecret: deviceSecret,
    );
    _json(response, 200, <String, Object?>{
      'access_token': accessToken,
      'token_type': requiresDpop ? 'DPoP' : 'Bearer',
      'expires_in': 900,
      'refresh_token': refreshToken,
      'id_token': ?(omitsIdTokenOnRefresh && isRefresh ? null : idToken),
      'scope': scope,
      'device_secret': ?deviceSecret,
      'issued_token_type': ?issuedTokenType,
    });
  }

  /// An `at+jwt` access token (RFC 9068) shaped like the real issuer's:
  /// `aud` is the API ([resource], or the client's only API) or the issuer
  /// for LoginFlow's own token, which lists no permissions; `org_id` /
  /// `org_ext` name the active organization; `permissions` are that API's
  /// only, or `permissions_overage: true` when they do not fit.
  String _accessToken({
    required String clientId,
    required FakeUser user,
    required String sid,
    required String scope,
    required FakeOrganization? organization,
    required String? resource,
  }) {
    final apis = clientApis[clientId] ?? const <String>{};
    final api = resource == issuerText
        ? null
        : resource ?? (apis.length == 1 ? apis.single : null);
    final permissions = api == null
        ? null
        : organization?.permissions[api] ?? const <String>[];
    final isOverage =
        permissions != null &&
        (permissions.length > maxTokenPermissions ||
            utf8.encode(jsonEncode(permissions)).length >
                maxPermissionsClaimBytes);
    final now = DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000;
    return keys.sign(<String, Object?>{
      'iss': issuerText,
      'sub': user.subject,
      'aud': api ?? issuerText,
      'app': applicationId,
      'client_id': clientId,
      'exp': now + 600,
      'iat': now,
      'jti': _token32(),
      'sid': sid,
      'scope': scope,
      'org_id': ?organization?.id,
      'org_ext': ?organization?.externalId,
      if (permissions != null && !isOverage) 'permissions': permissions,
      if (isOverage) 'permissions_overage': true,
    }, type: 'at+jwt');
  }

  /// The active organization for [user] (`resolve_active_organization`,
  /// `doc/server-contract.md` §17): [requested] when the user has an
  /// assignment there, unavailable when not; without a request, the only one, or none.
  ({FakeOrganization? active, bool isUnavailable}) _resolveOrganization(
    FakeUser user, {
    required String? requested,
  }) {
    final eligible =
        organizationsBySubject[user.subject] ?? const <FakeOrganization>[];
    if (requested != null) {
      for (final organization in eligible) {
        if (organization.id == requested) {
          return (active: organization, isUnavailable: false);
        }
      }
      return (active: null, isUnavailable: true);
    }
    return (
      active: eligible.length == 1 ? eligible.single : null,
      isUnavailable: false,
    );
  }

  /// Whether [organizationId] is an organization of the application at
  /// all; an opening request naming any other is `invalid_request`.
  bool _isKnownOrganization(String? organizationId) =>
      organizationId == null ||
      organizationsBySubject.values.any(
        (organizations) => organizations.any(
          (organization) => organization.id == organizationId,
        ),
      );

  String _idToken({
    required String clientId,
    required FakeUser user,
    required String sid,
    required String? nonce,
    required String? deviceSecret,
  }) {
    final now = DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000;
    final claims = <String, Object?>{
      'iss': tampering == IdTokenTampering.wrongIssuer
          ? 'https://evil.example'
          : issuerText,
      'sub': user.subject,
      'aud': tampering == IdTokenTampering.wrongAudience
          ? 'another-client'
          : clientId,
      'exp': tampering == IdTokenTampering.expired ? now - 3600 : now + 3600,
      'iat': tampering == IdTokenTampering.expired ? now - 7200 : now,
      'auth_time': now,
      'sid': sid,
      'amr': <String>['pwd'],
      'company_id': companyId,
      'email': ?user.email,
      'email_verified': user.email != null,
      'name': ?user.name,
      'ext_sub': ?user.externalSubject,
      'subject_kind': ?user.subjectKind,
      'ext_profile': ?user.subjectProfile,
      if (nonce != null)
        'nonce': tampering == IdTokenTampering.wrongNonce
            ? 'not-the-nonce'
            : nonce,
      if (deviceSecret != null) 'ds_hash': _deviceSecretHash(deviceSecret),
    };
    var token = keys.sign(
      claims,
      algorithm: idTokenAlgorithm,
      type: tampering == IdTokenTampering.accessTokenType ? 'at+jwt' : 'JWT',
    );
    if (tampering == IdTokenTampering.badSignature) {
      final parts = token.split('.');
      final forged = Map<String, Object?>.of(claims)..['sub'] = 'cu_mallory';
      token =
          '${parts[0]}.${utf8.encode(jsonEncode(forged)).toBase64UrlNoPadding()}.${parts[2]}';
    }
    if (tampering == IdTokenTampering.algorithmNone) {
      final header = utf8
          .encode(jsonEncode(<String, Object?>{'alg': 'none', 'kid': 'x'}))
          .toBase64UrlNoPadding();
      token = '$header.${token.split('.')[1]}.AAAA';
    }
    if (deviceSecret != null) {
      _idTokenDeviceSecretHash[token] = _deviceSecretHash(deviceSecret);
    }
    return token;
  }

  /// RFC 7009 §2.1: only the client the token was issued to may revoke it;
  /// unknown tokens answer 200 (§2.2).
  void _revoke(FakeHttpResponse response, Map<String, String> form) {
    final record = _refreshTokens[form['token']];
    if (record != null && record.clientId != form['client_id']) {
      return _oauthError(response, 400, 'unauthorized_client');
    }
    if (record != null) {
      _revokedFamilies.add(record.familyId);
    }
    response.statusCode = 200;
  }

  void _endSessions(
    FakeHttpRequest request,
    FakeHttpResponse response, {
    required bool everywhere,
  }) {
    final header = request.headers['authorization'] ?? '';
    final token = switch (header) {
      final value when value.startsWith('Bearer ') => value.substring(7),
      final value when value.startsWith('DPoP ') => value.substring(5),
      _ => '',
    };
    final access = _liveAccess(token);
    if (access == null) {
      return _refuseToken(response, header);
    }
    if (everywhere) {
      globalLogoutTokens.add(token);
      for (final session in _deviceSessions.values) {
        if (session.subject == access.subject) {
          session.isActive = false;
        }
      }
    } else {
      deviceLogoutTokens.add(token);
      _deviceSessions[access.sid]?.isActive = false;
    }
    response.statusCode = 204;
  }

  /// The record of an access token the resource middleware still accepts:
  /// known, and its device session (`sid`) not ended.
  _AccessRecord? _liveAccess(String token) {
    final access = _accessTokens[token];
    return access != null && isDeviceSessionActive(access.sid) ? access : null;
  }

  /// `401` + `WWW-Authenticate: <scheme> error="invalid_token"`, no body
  /// (`jwt_middleware::token_challenge_response`).
  void _refuseToken(FakeHttpResponse response, String authorization) {
    final scheme = authorization.startsWith('DPoP ') ? 'DPoP' : 'Bearer';
    response
      ..statusCode = 401
      ..headers['www-authenticate'] = '$scheme error="invalid_token"';
  }

  void _userProfile(FakeHttpRequest request, FakeHttpResponse response) {
    final header = request.headers['authorization'] ?? '';
    final scheme = requiresDpop ? 'DPoP ' : 'Bearer ';
    final access = header.startsWith(scheme)
        ? _liveAccess(header.substring(scheme.length))
        : null;
    if (access == null) {
      return _refuseToken(response, header);
    }
    _json(response, 200, <String, Object?>{'sub': access.subject});
  }

  /// `GET /oauth2/organizations`: the caller's eligible organizations and
  /// the one its token is issued for.
  void _listOrganizations(FakeHttpRequest request, FakeHttpResponse response) {
    final header = request.headers['authorization'] ?? '';
    final scheme = requiresDpop ? 'DPoP ' : 'Bearer ';
    final access = header.startsWith(scheme)
        ? _liveAccess(header.substring(scheme.length))
        : null;
    if (access == null) {
      return _refuseToken(response, header);
    }
    final organizations =
        organizationsBySubject[access.subject] ?? const <FakeOrganization>[];
    _json(response, 200, <String, Object?>{
      'active': access.organizationId,
      'organizations': <Object?>[
        for (final organization in organizations) organization.toJson(),
      ],
    });
  }

  /// `POST /v1/user/passkeys/enroll/start`: `webauthn-rs`'s
  /// `CreationChallengeResponse` is opaque to the client, so any JSON
  /// object under `data` is enough to exercise the envelope.
  void _passkeysEnrollStart(
    FakeHttpRequest request,
    FakeHttpResponse response,
  ) {
    final access = _authenticatedPasskeyCaller(request, response);
    if (access == null) {
      return;
    }
    if (_staleAuthentications.contains(access.sid)) {
      response.headers['www-authenticate'] =
          'Bearer error="insufficient_user_authentication", max_age=300';
      return _envelopeError(
        response,
        401,
        'UNAUTHORIZED',
        'Authentication is required.',
      );
    }
    final body = jsonDecode(request.body) as Map<String, Object?>;
    _envelopeSuccess(response, 200, <String, Object?>{
      'challenge': _token32(),
      'rp': <String, Object?>{'id': issuer.host, 'name': 'LoginFlow'},
      'user': <String, Object?>{
        'id': _token32(),
        'name': body['username'],
        'displayName': body['display_name'],
      },
    });
  }

  /// `POST /v1/user/passkeys/enroll/finish`.
  void _passkeysEnrollFinish(
    FakeHttpRequest request,
    FakeHttpResponse response,
  ) {
    final access = _authenticatedPasskeyCaller(request, response);
    if (access == null) {
      return;
    }
    final body = jsonDecode(request.body) as Map<String, Object?>;
    final credential = body['credential'] as Map<String, Object?>?;
    final id = credential?['id'] as String? ?? 'credential-${_token32()}';
    final enrolled = _EnrolledPasskey(
      id: id,
      name: body['name'] as String?,
      createdAt: DateTime.now().toUtc(),
      lastUsedAt: null,
      owner: access.subject,
    );
    _enrolledPasskeys[id] = enrolled;
    _envelopeSuccess(response, 201, enrolled.toJson());
  }

  /// `GET /v1/user/passkeys` — only the caller's own credentials.
  void _passkeysList(FakeHttpRequest request, FakeHttpResponse response) {
    final access = _authenticatedPasskeyCaller(request, response);
    if (access == null) {
      return;
    }
    final items = _enrolledPasskeys.values
        .where((passkey) => passkey.owner == access.subject)
        .map((passkey) => passkey.toJson())
        .toList();
    _envelopeSuccess(response, 200, items);
  }

  /// `PATCH /v1/user/passkeys/{id}`.
  void _passkeysRename(
    FakeHttpRequest request,
    FakeHttpResponse response,
    String id,
  ) {
    final access = _authenticatedPasskeyCaller(request, response);
    if (access == null) {
      return;
    }
    final enrolled = _enrolledPasskeys[id];
    if (enrolled == null || enrolled.owner != access.subject) {
      return _envelopeError(response, 404, 'not_found', 'Passkey not found.');
    }
    final body = jsonDecode(request.body) as Map<String, Object?>;
    final renamed = enrolled.copyWith(name: body['name'] as String?);
    _enrolledPasskeys[id] = renamed;
    _envelopeSuccess(response, 200, renamed.toJson());
  }

  /// `DELETE /v1/user/passkeys/{id}`.
  void _passkeysDelete(
    FakeHttpRequest request,
    FakeHttpResponse response,
    String id,
  ) {
    final access = _authenticatedPasskeyCaller(request, response);
    if (access == null) {
      return;
    }
    final enrolled = _enrolledPasskeys[id];
    if (enrolled == null || enrolled.owner != access.subject) {
      return _envelopeError(response, 404, 'not_found', 'Passkey not found.');
    }
    _enrolledPasskeys.remove(id);
    _envelopeSuccess(response, 200, <String, Object?>{
      'message': 'Passkey removed',
    });
  }

  /// LoginFlow's members API for a person (`doc/server-contract.md` §18).
  static const String membersPath = '/v1/app/members';

  /// The organizations the members API knows, keyed by id: their grantable
  /// roles (for the signed-in user) and their members. Empty by default:
  /// every organization is `404 organization_not_found`.
  final Map<String, FakeMembersOrganization> membersOrganizations =
      <String, FakeMembersOrganization>{};

  /// Every request that reached the members API, in order.
  final List<FakeHttpRequest> membersRequests = <FakeHttpRequest>[];

  int _assignmentSequence = 0;

  /// `require_dpop_bound_loginflow_token`, then the route: a DPoP-bound
  /// token (`401 DPoP error="invalid_token"` otherwise) for LoginFlow itself
  /// (`403 wrong_audience` for a product API's token), a recent sign-in on
  /// every write (RFC 9470 `401`), and the delegation refusals as
  /// `error.code` — the shapes `app_members_handler.rs` answers.
  void _members(
    FakeHttpRequest request,
    FakeHttpResponse response,
    String method,
    String route,
  ) {
    membersRequests.add(request);
    final header = request.headers['authorization'] ?? '';
    final access = header.startsWith('DPoP ')
        ? _liveAccess(header.substring(5))
        : null;
    if (access == null || _checkDpop(request, response) != null) {
      response
        ..statusCode = 401
        ..headers['www-authenticate'] = 'DPoP error="invalid_token"';
      return;
    }
    if (access.audience != issuerText) {
      return _envelopeError(response, 403, 'wrong_audience', 'Wrong audience');
    }
    final isWrite = method != 'GET';
    if (isWrite && _staleAuthentications.contains(access.sid)) {
      response.headers['www-authenticate'] =
          'Bearer error="insufficient_user_authentication", max_age=300';
      return _envelopeError(
        response,
        401,
        'UNAUTHORIZED',
        'Authentication is required.',
      );
    }
    final query = request.uri.queryParameters;
    final body = isWrite && request.body.isNotEmpty
        ? jsonDecode(request.body) as Map<String, Object?>
        : const <String, Object?>{};
    switch ((method, route)) {
      case ('GET', '/grantable-roles'):
        if (!_onlyKeys(query.keys, const <String>{'organization_id'})) {
          return _envelopeError(response, 400, 'BAD_REQUEST', 'Bad query');
        }
        final organization = membersOrganizations[query['organization_id']];
        if (organization == null) {
          return _organizationNotFound(response);
        }
        _envelopeSuccess(response, 200, <String, Object?>{
          'organization': organization.summary,
          'roles': organization.grantableRoles,
        });
      case ('GET', ''):
        const accepted = <String>{'organization_id', 'q', 'limit', 'offset'};
        if (!_onlyKeys(query.keys, accepted)) {
          return _envelopeError(response, 400, 'BAD_REQUEST', 'Bad query');
        }
        final organization = membersOrganizations[query['organization_id']];
        if (organization == null) {
          return _organizationNotFound(response);
        }
        final needle = query['q'];
        final items = organization.members
            .where(
              (member) =>
                  needle == null ||
                  (member['email']! as String).contains(needle),
            )
            .toList();
        _envelopeSuccess(response, 200, <String, Object?>{
          'items': items,
          'total': items.length,
        });
      case ('POST', '/invitations'):
        const accepted = <String>{
          'organization_id',
          'email',
          'first_name',
          'last_name',
          'role_id',
          'expires_at',
        };
        if (!_onlyKeys(body.keys, accepted)) {
          return _envelopeError(response, 400, 'BAD_REQUEST', 'Unknown field');
        }
        final caller = users.values
            .where((user) => user.subject == access.subject)
            .firstOrNull;
        if (caller?.email == body['email']) {
          return _denied(response, 403, 'self_assignment_forbidden');
        }
        final granted = _grantIn(response, body);
        if (granted == null) {
          return;
        }
        final email = body['email']! as String;
        final isKnown = users.containsKey(email);
        _envelopeSuccess(response, 201, <String, Object?>{
          'member': <String, Object?>{
            'principal_id': users[email]?.subject ?? 'cu_invited',
            'email': email,
            'name': body['first_name'],
          },
          'assignment': granted,
          'invitation': isKnown ? 'not_needed' : 'sent',
        });
      case ('POST', final path) when path.endsWith('/assignments'):
        if (!_onlyKeys(body.keys, const <String>{
          'organization_id',
          'role_id',
          'expires_at',
        })) {
          return _envelopeError(response, 400, 'BAD_REQUEST', 'Unknown field');
        }
        final principal = Uri.decodeComponent(path.split('/')[1]);
        if (principal == access.subject) {
          return _denied(response, 403, 'self_assignment_forbidden');
        }
        final granted = _grantIn(response, body);
        if (granted != null) {
          _envelopeSuccess(response, 201, granted);
        }
      case ('DELETE', final path) when path.startsWith('/assignments/'):
        final id = Uri.decodeComponent(path.substring('/assignments/'.length));
        final isKnown = membersOrganizations.values.any(
          (organization) => organization.members.any(
            (member) => (member['assignments']! as List<Object?>).any(
              (assignment) => (assignment! as Map<String, Object?>)['id'] == id,
            ),
          ),
        );
        if (!isKnown) {
          return _denied(response, 404, 'assignment_not_found');
        }
        response.statusCode = 204;
      default:
        _envelopeError(response, 404, 'NOT_FOUND', 'No such route');
    }
  }

  /// The assignment a grant of `role_id` in `organization_id` creates, or
  /// `null` after writing the refusal: `404 organization_not_found`, `403
  /// role_not_grantable` for a role outside the caller's grantable list.
  Map<String, Object?>? _grantIn(
    FakeHttpResponse response,
    Map<String, Object?> body,
  ) {
    final organization = membersOrganizations[body['organization_id']];
    if (organization == null) {
      _organizationNotFound(response);
      return null;
    }
    final role = organization.grantableRoles
        .where((role) => role['id'] == body['role_id'])
        .firstOrNull;
    if (role == null) {
      _denied(response, 403, 'role_not_grantable');
      return null;
    }
    _assignmentSequence++;
    return <String, Object?>{
      'id': 'as_$_assignmentSequence',
      'role': <String, Object?>{
        'id': role['id'],
        'key': role['key'],
        'name': role['name'],
      },
      'expires_at': body['expires_at'],
      'manageable': true,
    };
  }

  void _organizationNotFound(FakeHttpResponse response) =>
      _denied(response, 404, 'organization_not_found');

  void _denied(FakeHttpResponse response, int status, String code) =>
      _envelopeError(response, status, code, 'Refused: $code');

  static bool _onlyKeys(Iterable<String> keys, Set<String> accepted) =>
      keys.every(accepted.contains);

  /// LoginFlow's self-service email change for a person
  /// (`loginflow_api/docs/api/v1/app/email-change/`).
  static const String emailChangePath = '/v1/app/email-change';

  /// The step-up a credential WITH a second factor needs to start a change:
  /// a recent strong sign-in (`strong_recent_auth_required`).
  static const String strongStepUpChallenge =
      'Bearer error="insufficient_user_authentication", '
      'acr_values="urn:loginflow:acr:phr urn:loginflow:acr:mfa", max_age=300';

  /// The step-up a credential WITHOUT a second factor needs: a recent
  /// sign-in, any `acr` (`recent_auth_required`).
  static const String recentStepUpChallenge =
      'Bearer error="insufficient_user_authentication", max_age=300';

  /// `rate_limit::EMAIL_CHANGE`: starts per person and application per hour.
  static const int emailChangeStartsPerHour = 3;

  /// The `Retry-After` of a start past [emailChangeStartsPerHour].
  static const Duration emailChangeRetryAfter = Duration(minutes: 42);

  /// Every request that reached the email-change routes, in order.
  final List<FakeHttpRequest> emailChangeRequests = <FakeHttpRequest>[];

  /// Every code the email-change routes emailed, in order.
  final List<FakeSentCode> sentEmailChangeCodes = <FakeSentCode>[];

  final Map<String, int> _emailChangeStarts = <String, int>{};
  final Map<String, _EmailChangeRequest> _openEmailChanges =
      <String, _EmailChangeRequest>{};

  /// The code emailed to [address] by the latest start, if any.
  String? emailChangeCodeSentTo(String address) => sentEmailChangeCodes
      .where((sent) => sent.address == address)
      .lastOrNull
      ?.code;

  /// `require_dpop_bound_loginflow_token`, then the route — the shapes
  /// `email_change_handler.rs` answers.
  void _emailChange(
    FakeHttpRequest request,
    FakeHttpResponse response,
    String method,
    String route,
  ) {
    emailChangeRequests.add(request);
    final header = request.headers['authorization'] ?? '';
    final access = header.startsWith('DPoP ')
        ? _liveAccess(header.substring(5))
        : null;
    if (access == null || _checkDpop(request, response) != null) {
      response
        ..statusCode = 401
        ..headers['www-authenticate'] = 'DPoP error="invalid_token"';
      return;
    }
    if (access.audience != issuerText) {
      return _envelopeError(response, 403, 'wrong_audience', 'Wrong audience');
    }
    final user = _userBySubject(access.subject);
    if (user == null || user.subjectKind != null) {
      return _envelopeError(
        response,
        403,
        'permission_denied',
        'Permission denied',
      );
    }
    final body = request.body.isEmpty
        ? const <String, Object?>{}
        : jsonDecode(request.body) as Map<String, Object?>;
    switch ((method, route)) {
      case ('POST', ''):
        _startEmailChange(response, access, user, body);
      case ('POST', '/confirm'):
        _confirmEmailChange(response, access, user, body);
      default:
        _envelopeError(response, 404, 'NOT_FOUND', 'No such route');
    }
  }

  /// `EmailChangeService::start`: the step-up the credential requires, the
  /// address, the hourly limit, then a new request whose codes are emailed
  /// — never to an address another identity holds (the same `202`).
  void _startEmailChange(
    FakeHttpResponse response,
    _AccessRecord access,
    FakeUser user,
    Map<String, Object?> body,
  ) {
    final newEmail = body['new_email'];
    if (newEmail is! String || !_onlyKeys(body.keys, const {'new_email'})) {
      return _envelopeError(response, 400, 'BAD_REQUEST', 'Bad request');
    }
    final hasSecondFactor = _hasSecondFactor(user);
    final isStale = _staleAuthentications.contains(access.sid);
    final isStrong = _deviceSessions[access.sid]?.isStrong ?? false;
    if (hasSecondFactor && (isStale || !isStrong)) {
      return _authenticationRequired(response, strongStepUpChallenge);
    }
    if (isStale) {
      return _authenticationRequired(response, recentStepUpChallenge);
    }
    final address = newEmail.trim();
    final isValid =
        RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(address) &&
        !address.toLowerCase().endsWith('@mailinator.com');
    if (!isValid) {
      return _validationError(
        response,
        'The submitted data contains invalid characters or does not have '
        'the required format.',
      );
    }
    final current = user.email ?? '';
    if (address.toLowerCase() == current.toLowerCase()) {
      return _validationError(response, 'The new email is the current email');
    }
    final starts = (_emailChangeStarts[user.subject] ?? 0) + 1;
    _emailChangeStarts[user.subject] = starts;
    if (starts > emailChangeStartsPerHour) {
      response.headers['retry-after'] = '${emailChangeRetryAfter.inSeconds}';
      return _envelopeError(
        response,
        429,
        'RATE_LIMITED',
        'Too many attempts. Try again later.',
      );
    }
    final pending = _EmailChangeRequest(
      newEmail: address,
      code: _sixDigits(),
      currentCode: hasSecondFactor ? null : _sixDigits(),
      expiresAt: DateTime.now().toUtc().add(const Duration(minutes: 15)),
    );
    _openEmailChanges[user.subject] = pending;
    if (!_isEmailTaken(address, bySubjectOtherThan: user.subject)) {
      sentEmailChangeCodes.add((address: address, code: pending.code));
    }
    final currentCode = pending.currentCode;
    if (currentCode != null) {
      sentEmailChangeCodes.add((address: current, code: currentCode));
    }
    final expiresAt = pending.expiresAt.toIso8601String();
    _envelopeSuccess(response, 202, <String, Object?>{
      // A `NaiveDateTime`: UTC without an offset, whole seconds.
      'expires_at': expiresAt.substring(0, expiresAt.indexOf('.')),
      'confirm_current': currentCode != null,
    });
  }

  /// `EmailChangeService::confirm`: each code claims one attempt of its own
  /// counter; any refusal is the same `401 INVALID_CODE`. A confirmed change
  /// sets the profile's email and ends every OTHER session of the person.
  void _confirmEmailChange(
    FakeHttpResponse response,
    _AccessRecord access,
    FakeUser user,
    Map<String, Object?> body,
  ) {
    final code = body['code'];
    final currentCode = body['current_code'];
    if (code is! String ||
        (currentCode != null && currentCode is! String) ||
        !_onlyKeys(body.keys, const {'code', 'current_code'})) {
      return _envelopeError(response, 400, 'BAD_REQUEST', 'Bad request');
    }
    final sixDigits = RegExp(r'^\d{6}$');
    if (!sixDigits.hasMatch(code) ||
        (currentCode is String && !sixDigits.hasMatch(currentCode))) {
      return _validationError(response, 'The code must be 6 digits');
    }
    final pending = _openEmailChanges[user.subject];
    if (pending == null ||
        DateTime.now().toUtc().isAfter(pending.expiresAt) ||
        pending.attempts >= 5) {
      return _invalidCode(response);
    }
    pending.attempts++;
    if (code != pending.code) {
      return _invalidCode(response);
    }
    final expectedCurrent = pending.currentCode;
    if (expectedCurrent != null) {
      if (currentCode == null || pending.currentAttempts >= 5) {
        return _invalidCode(response);
      }
      pending.currentAttempts++;
      if (currentCode != expectedCurrent) {
        return _invalidCode(response);
      }
    }
    if (_isEmailTaken(pending.newEmail, bySubjectOtherThan: user.subject)) {
      return _invalidCode(response);
    }
    _openEmailChanges.remove(user.subject);
    users
      ..remove(user.email)
      ..[pending.newEmail] = user.copyWith(email: pending.newEmail);
    for (final MapEntry(key: sid, value: session) in _deviceSessions.entries) {
      if (session.subject == user.subject && sid != access.sid) {
        session.isActive = false;
      }
    }
    _envelopeSuccess(response, 200, <String, Object?>{
      'email': pending.newEmail,
      'email_verified': true,
    });
  }

  /// LoginFlow's TOTP account API (`loginflow_api/docs/api/v1/user/totp/`).
  static const String totpPath = '/v1/user/totp';

  /// The secret every TOTP setup hands out; [totpCode] is its code.
  static const String totpSecret = 'JBSWY3DPEHPK3PXP';

  /// Every request that reached the TOTP routes, in order.
  final List<FakeHttpRequest> totpRequests = <FakeHttpRequest>[];

  /// Subjects with a secret set up and not confirmed yet.
  final Set<String> _pendingTotp = <String>{};

  /// When each subject's TOTP was confirmed.
  final Map<String, DateTime> _totpVerifiedAt = <String, DateTime>{};

  /// `authenticate_access` + `refuse_access_subject`, then the route — the
  /// shapes `totp_handler.rs` and `recovery_code_handler.rs` answer.
  void _totp(
    FakeHttpRequest request,
    FakeHttpResponse response,
    String method,
    String route,
  ) {
    totpRequests.add(request);
    final header = request.headers['authorization'] ?? '';
    final scheme = requiresDpop ? 'DPoP ' : 'Bearer ';
    final access = header.startsWith(scheme)
        ? _liveAccess(header.substring(scheme.length))
        : null;
    if (access == null ||
        (requiresDpop && _checkDpop(request, response) != null)) {
      return _refuseToken(response, header);
    }
    final user = _userBySubject(access.subject);
    if (user == null || user.subjectKind != null) {
      return _envelopeError(
        response,
        403,
        'not_available_for_access_subject',
        'This account route is not available to an access-code subject',
      );
    }
    final body = request.body.isEmpty
        ? const <String, Object?>{}
        : jsonDecode(request.body) as Map<String, Object?>;
    switch ((method, route)) {
      case ('GET', '/status'):
        final verifiedAt = _totpVerifiedAt[user.subject]?.toIso8601String();
        _envelopeSuccess(response, 200, <String, Object?>{
          'enabled': user.isTotpEnabled,
          // A `NaiveDateTime` formatted `%Y-%m-%dT%H:%M:%S`: UTC, no offset.
          'verified_at': verifiedAt?.substring(0, verifiedAt.indexOf('.')),
        });
      case ('POST', '/setup'):
        _pendingTotp.add(user.subject);
        final issuer = (body['issuer'] as String?)?.trim() ?? 'Fake App';
        _envelopeSuccess(response, 200, <String, Object?>{
          'secret': totpSecret,
          'otpauth_uri':
              'otpauth://totp/${Uri.encodeComponent(issuer)}:'
              '${Uri.encodeComponent(user.email ?? '')}?secret=$totpSecret'
              '&issuer=${Uri.encodeComponent(issuer)}'
              '&algorithm=SHA1&digits=6&period=30',
          'issuer': issuer,
        });
      case ('POST', '/verify-setup'):
        if (user.isTotpEnabled) {
          return _envelopeError(
            response,
            400,
            'BAD_REQUEST',
            'TOTP is already enabled',
          );
        }
        if (!_pendingTotp.contains(user.subject)) {
          return _envelopeError(
            response,
            400,
            'BAD_REQUEST',
            'TOTP setup not initiated. Call setup first.',
          );
        }
        if (body['code'] != totpCode) {
          return _invalidTotpCode(response);
        }
        _pendingTotp.remove(user.subject);
        _totpVerifiedAt[user.subject] = DateTime.now().toUtc();
        _replaceUser(user, user.copyWith(isTotpEnabled: true));
        _envelopeSuccess(response, 200, <String, Object?>{
          'message': 'TOTP 2FA enabled successfully',
        });
      case ('POST', '/disable'):
        if (!user.isTotpEnabled) {
          return _envelopeError(
            response,
            400,
            'BAD_REQUEST',
            'TOTP is not enabled',
          );
        }
        if (body['code'] != totpCode) {
          return _invalidTotpCode(response);
        }
        _totpVerifiedAt.remove(user.subject);
        _replaceUser(user, user.copyWith(isTotpEnabled: false));
        _envelopeSuccess(response, 200, <String, Object?>{
          'message': 'TOTP 2FA disabled successfully',
        });
      case ('POST', '/recovery-codes'):
        if (_staleAuthentications.contains(access.sid)) {
          return _authenticationRequired(response, recentStepUpChallenge);
        }
        _envelopeSuccess(response, 200, <String, Object?>{
          'recovery_codes': <String>[
            for (var index = 0; index < 10; index++) _sixDigits(),
          ],
        });
      default:
        _envelopeError(response, 404, 'NOT_FOUND', 'No such route');
    }
  }

  void _invalidTotpCode(FakeHttpResponse response) =>
      _envelopeError(response, 401, 'INVALID_CODE', 'Invalid TOTP code');

  void _replaceUser(FakeUser user, FakeUser replacement) {
    final key = users.entries
        .firstWhere((entry) => entry.value.subject == user.subject)
        .key;
    users[key] = replacement;
  }

  /// TOTP enabled or at least one passkey.
  bool _hasSecondFactor(FakeUser user) =>
      user.isTotpEnabled ||
      passkeyCredentialOwners.containsValue(user.email) ||
      _enrolledPasskeys.values.any((passkey) => passkey.owner == user.subject);

  bool _isEmailTaken(String email, {required String bySubjectOtherThan}) =>
      users.values.any(
        (other) =>
            other.subject != bySubjectOtherThan &&
            other.email?.toLowerCase() == email.toLowerCase(),
      );

  FakeUser? _userBySubject(String subject) =>
      users.values.where((user) => user.subject == subject).firstOrNull;

  void _authenticationRequired(FakeHttpResponse response, String challenge) {
    response.headers['www-authenticate'] = challenge;
    _envelopeError(
      response,
      401,
      'UNAUTHORIZED',
      'Authentication is required.',
    );
  }

  void _validationError(FakeHttpResponse response, String details) =>
      _envelopeError(
        response,
        422,
        'VALIDATION_ERROR',
        'Some fields are invalid.',
        details: details,
      );

  void _invalidCode(FakeHttpResponse response) => _envelopeError(
    response,
    401,
    'INVALID_CODE',
    'The code is invalid or has expired',
  );

  String _sixDigits() => _random.nextInt(1000000).toString().padLeft(6, '0');

  /// The caller of a `/v1/user/passkeys*` request, or `null` after writing a
  /// `401` to [response] — same Bearer/DPoP check as [_userProfile] — or
  /// the `403` of [passkeyAccountRefusal].
  _AccessRecord? _authenticatedPasskeyCaller(
    FakeHttpRequest request,
    FakeHttpResponse response,
  ) {
    final header = request.headers['authorization'] ?? '';
    final scheme = requiresDpop ? 'DPoP ' : 'Bearer ';
    final access = header.startsWith(scheme)
        ? _liveAccess(header.substring(scheme.length))
        : null;
    if (access == null) {
      response
        ..statusCode = 401
        ..headers['www-authenticate'] =
            '${scheme.trim()} error="invalid_token"';
      return null;
    }
    final refusal = passkeyAccountRefusal;
    if (refusal != null) {
      _envelopeError(response, 403, refusal, 'Passkeys are not available.');
      return null;
    }
    return access;
  }

  /// LoginFlow's standard success envelope (`response_entity.rs`'s
  /// `ApiResponse::success`/`created`): `{"data": <payload>, "meta": {...}}`.
  void _envelopeSuccess(FakeHttpResponse response, int status, Object? data) {
    _json(response, status, <String, Object?>{
      'data': data,
      'meta': _envelopeMeta(status),
    });
  }

  /// LoginFlow's standard error envelope (`ApiResponse::error`):
  /// `{"error": {"code", "message"}, "meta": {...}}`.
  void _envelopeError(
    FakeHttpResponse response,
    int status,
    String code,
    String message, {
    String? details,
  }) {
    _json(response, status, <String, Object?>{
      'error': <String, Object?>{
        'code': code,
        'message': message,
        'details': ?details,
      },
      'meta': _envelopeMeta(status),
    });
  }

  Map<String, Object?> _envelopeMeta(int status) => <String, Object?>{
    'status': status,
    'timestamp': DateTime.now().toUtc().toIso8601String(),
    'request_id': 'req_${_token32()}',
    'path': passkeysCollectionPath,
  };

  /// Validates the `DPoP` header against RFC 9449 §4.3: well-formed proof
  /// JWT, `typ: dpop+jwt`, `alg: ES256`, signature verifies against its own
  /// embedded `jwk`, `htm`/`htu` match this request, `jti` single use, and
  /// (on a resource request with `Authorization: DPoP <token>`) `ath`
  /// matches the token. Returns `null` when valid, or the `error` code to
  /// answer with; stamps `DPoP-Nonce` on [response] when a nonce challenge
  /// is pending.
  String? _checkDpop(FakeHttpRequest request, FakeHttpResponse response) {
    final nextNonce = nextDpopNonceChallenge;
    if (nextNonce != null) {
      nextDpopNonceChallenge = null;
      _requiredDpopNonce = nextNonce;
      response.headers['dpop-nonce'] = nextNonce;
      return 'use_dpop_nonce';
    }
    final header = request.headers['dpop'];
    if (header == null) {
      return 'invalid_dpop_proof';
    }
    final proof = _parseDpopProof(header);
    if (proof == null) {
      return 'invalid_dpop_proof';
    }
    if (proof.httpMethod != request.method ||
        proof.httpUri != request.uri.path) {
      return 'invalid_dpop_proof';
    }
    if (!_usedDpopJti.add(proof.jwtId)) {
      return 'invalid_dpop_proof';
    }
    final requiredNonce = _requiredDpopNonce;
    if (requiredNonce != null && proof.nonce != requiredNonce) {
      response.headers['dpop-nonce'] = requiredNonce;
      return 'use_dpop_nonce';
    }
    final authorization = request.headers['authorization'];
    if (authorization != null && authorization.startsWith('DPoP ')) {
      final presentedToken = authorization.substring(5);
      if (proof.accessTokenHash != presentedToken.toAccessTokenHash()) {
        return 'invalid_dpop_proof';
      }
    }
    acceptedDpopThumbprints.add(proof.jwkThumbprint);
    return null;
  }

  _DpopProof? _parseDpopProof(String token) {
    final parts = token.split('.');
    if (parts.length != 3) {
      return null;
    }
    final headerBytes = parts[0].tryDecodeBase64Url();
    final payloadBytes = parts[1].tryDecodeBase64Url();
    if (headerBytes == null || payloadBytes == null) {
      return null;
    }
    final Map<String, Object?> header;
    final Map<String, Object?> payload;
    try {
      header = jsonDecode(utf8.decode(headerBytes)) as Map<String, Object?>;
      payload = jsonDecode(utf8.decode(payloadBytes)) as Map<String, Object?>;
    } on FormatException {
      return null;
    }
    if (header['typ'] != 'dpop+jwt' || header['alg'] != 'ES256') {
      return null;
    }
    final jwkJson = header['jwk'];
    if (jwkJson is! Map<String, Object?>) {
      return null;
    }
    final jwk = JsonWebKey.fromJson(jwkJson);
    final jws = CompactJws(
      header: const JwsHeader(algorithm: 'ES256', type: 'dpop+jwt'),
      payloadJson: utf8.decode(payloadBytes),
      signingInput: '${parts[0]}.${parts[1]}',
      signature: parts[2],
    );
    if (!const JwsSignatureVerifier().verify(jws, jwk)) {
      return null;
    }
    final jti = payload['jti'];
    if (jti is! String) {
      return null;
    }
    return _DpopProof(
      httpMethod: payload['htm'] as String?,
      httpUri: Uri.tryParse(payload['htu'] as String? ?? '')?.path,
      jwtId: jti,
      accessTokenHash: payload['ath'] as String?,
      nonce: payload['nonce'] as String?,
      jwkThumbprint: '${jwk.x}:${jwk.y}',
    );
  }

  /// Every `403` rotates the `auth_session` (FIPA §5.3.1,
  /// `ChallengeService` `advance`): the value presented stops working.
  void _rotate(_ChallengeSession session) {
    _sessions.remove(session.key);
    session.key = _token32();
    _sessions[session.key] = session;
  }

  void _redirectToWeb(FakeHttpResponse response, _ChallengeSession session) {
    _rotate(session);
    final requestUri = 'urn:ietf:params:oauth:request_uri:${_token32()}';
    _pushedRequests[requestUri] = session.key;
    _json(response, 403, <String, Object?>{
      'error': 'redirect_to_web',
      'auth_session': session.key,
      'request_uri': requestUri,
      'expires_in': 60,
    });
  }

  void _step(
    FakeHttpResponse response,
    _ChallengeSession session,
    String next, {
    String? stepError,
    Map<String, Object?>? upstream,
    Map<String, Object?>? options,
  }) {
    _rotate(session);
    final methods = _stepMethods(next, users[session.email]);
    _json(response, 403, <String, Object?>{
      'error': 'insufficient_authorization',
      'auth_session': session.key,
      'next': next,
      // Omitted when empty (`InsufficientAuthorizationBody`,
      // `loginflow_api/src/features/login_engine/model/challenge_wire_model.rs:145-153`).
      if (methods.isNotEmpty) 'methods': methods,
      'step_error': ?stepError,
      'upstream': ?upstream,
      'options': ?options,
    });
  }

  /// The `methods` of the 403 answering [next], as the real server computes
  /// them for every step (`ChallengeService::step_methods`,
  /// `loginflow_api/src/features/login_engine/service/challenge_service.rs:1667-1689`):
  /// - `select_method`, `password`: the client's [_allowedLoginMethods]
  ///   alone, the same list for a known or an unknown identifier
  ///   (`client_step_methods`, `:1711-1718`);
  /// - `totp`, `recovery_code`: `totp`, plus `recovery_code` while the
  ///   account holds an unused one (`:1676-1686`);
  /// - any other step: none.
  List<String> _stepMethods(String next, FakeUser? user) => switch (next) {
    'select_method' => _allowedOf(_primaryStepMethods),
    'password' => _allowedOf(_passwordStepMethods),
    'totp' || 'recovery_code' => <String>[
      'totp',
      if (user?.hasUnusedRecoveryCodes ?? false) 'recovery_code',
    ],
    _ => const <String>[],
  };

  /// Wire names of [candidates] (wire name → `login_methods` name that
  /// allows it), in their order, that [_allowedLoginMethods] allows.
  List<String> _allowedOf(Map<String, String> candidates) => <String>[
    for (final MapEntry(key: wireName, value: allowedBy) in candidates.entries)
      if (_allowedLoginMethods.contains(allowedBy)) wireName,
  ];

  /// The client's [loginMethods] as the real server resolves them: `passkey`
  /// stays only while the company policy is [PasskeyMode.passwordless], the
  /// one policy under which a passkey is a first factor
  /// (`loginflow_api/src/features/oidc_provider/service/client_registry_service.rs:714-718`).
  List<String> get _allowedLoginMethods {
    final isPasskeyFirstFactor =
        hasPasskey && passkeyMode == PasskeyMode.passwordless;
    return <String>[
      for (final method in loginMethods)
        if (method != 'passkey' || isPasskeyFirstFactor) method,
    ];
  }

  /// Like the real API, a challenge code keeps the `redirect_uri` the opening
  /// request carried, and redeeming it must present that same value. The
  /// transaction is closed and keeps the `auth_session` just presented as
  /// its step-up handle; the `200` never carries a new one.
  String _issueChallengeCode(_ChallengeSession session, FakeUser user) {
    session.isCompleted = true;
    return _issueCode(
      session,
      user,
      redirectUri: session.redirectUri,
      organization: session.organization,
    );
  }

  String _issueCode(
    _ChallengeSession session,
    FakeUser user, {
    required String? redirectUri,
    required String? organization,
  }) {
    final code = 'code_${_token32()}';
    _codes[code] = _IssuedCode(
      clientId: session.clientId,
      codeChallenge: session.codeChallenge ?? '',
      nonce: session.nonce,
      scope: session.scope,
      user: user,
      redirectUri: redirectUri,
      organization: organization,
      isStrong: session.isSecondFactorDone,
    );
    return code;
  }

  String? _emailOfIdToken(String idToken) {
    final parts = idToken.split('.');
    if (parts.length != 3) {
      return null;
    }
    final payload = parts[1].tryDecodeBase64Url();
    if (payload == null) {
      return null;
    }
    final claims = jsonDecode(utf8.decode(payload)) as Map<String, Object?>;
    return claims['email'] as String?;
  }

  String _deviceSecretHash(String deviceSecret) =>
      utf8.encode('ds:$deviceSecret').toSha256().toBase64UrlNoPadding();

  String _token32() => List<int>.generate(
    24,
    (_) => _random.nextInt(256),
  ).toBase64UrlNoPadding();

  void _json(FakeHttpResponse response, int status, Map<String, Object?> body) {
    response
      ..statusCode = status
      ..body = jsonEncode(body);
    // UTF-8, like the real server (`ApiResponse` and the OAuth endpoints):
    // without the charset `dart:io` would write the body as Latin-1.
    response.headers['content-type'] = 'application/json; charset=utf-8';
  }

  void _oauthError(FakeHttpResponse response, int status, String error) =>
      _json(response, status, <String, Object?>{'error': error});

  void _redirect(FakeHttpResponse response, Uri location) {
    response.statusCode = 302;
    response.headers['location'] = location.toString();
  }
}

class _ChallengeSession {
  _ChallengeSession({required this.key, required this.clientId});

  /// The current `auth_session`; rotated by every `403`.
  String key;
  final String clientId;

  /// An authorization code was issued: the transaction is closed.
  bool isCompleted = false;
  String? codeChallenge;
  String? nonce;
  String scope = '';
  String? redirectUri;
  String? state;
  String? acrValues;
  String? organization;
  String? email;
  String? upstreamNonce;
  bool isPrimaryAuthenticated = false;
  bool isIdentifiedByHint = false;
  bool isSecondFactorDone = false;

  void openAuthorization({
    required String codeChallenge,
    required String? nonce,
    required String scope,
    required String? redirectUri,
    required String? state,
    required String? acrValues,
    required String? organization,
  }) {
    this.codeChallenge = codeChallenge;
    this.nonce = nonce;
    this.scope = scope;
    this.redirectUri = redirectUri;
    this.state = state;
    this.acrValues = acrValues;
    this.organization = organization;
    isSecondFactorDone = false;
  }
}

class _IssuedCode {
  const _IssuedCode({
    required this.clientId,
    required this.codeChallenge,
    required this.nonce,
    required this.scope,
    required this.user,
    required this.redirectUri,
    required this.organization,
    required this.isStrong,
  });

  final String clientId;
  final String codeChallenge;
  final String? nonce;
  final String scope;
  final FakeUser user;
  final String? redirectUri;
  final String? organization;

  /// A second factor (TOTP, a recovery code, a passkey) was done: the
  /// session's `acr` is multi-factor or phishing-resistant.
  final bool isStrong;
}

class _RefreshRecord {
  _RefreshRecord({
    required this.familyId,
    required this.clientId,
    required this.user,
    required this.scope,
    required this.sid,
  });

  final String familyId;
  final String clientId;
  final FakeUser user;
  final String scope;
  final String sid;
  bool isUsed = false;
}

class _DeviceSession {
  _DeviceSession({required this.subject, this.isStrong = false});

  final String subject;

  /// Signed in with a second factor (`acr` `urn:loginflow:acr:mfa` or
  /// `urn:loginflow:acr:phr`), what `recent_auth::is_strong_and_recent`
  /// reads.
  final bool isStrong;
  bool isActive = true;
}

/// A person's open email change (`email_change_requests`): the codes, the
/// attempts each one has used, and when they expire.
class _EmailChangeRequest {
  _EmailChangeRequest({
    required this.newEmail,
    required this.code,
    required this.currentCode,
    required this.expiresAt,
  });

  final String newEmail;
  final String code;

  /// The code sent to the CURRENT address; `null` for a credential with a
  /// second factor.
  final String? currentCode;
  final DateTime expiresAt;
  int attempts = 0;
  int currentAttempts = 0;
}

class _AccessRecord {
  const _AccessRecord({
    required this.subject,
    required this.sid,
    required this.organizationId,
    required this.audience,
  });

  final String subject;
  final String sid;
  final String? organizationId;

  /// The token's `aud`: an API, or the issuer for LoginFlow's own token.
  final String audience;
}

/// A passkey enrolled through the account API (`doc/server-contract.md`
/// §15), field names matching the real server's `PasskeyCredentialResponse`.
class _EnrolledPasskey {
  const _EnrolledPasskey({
    required this.id,
    required this.name,
    required this.createdAt,
    required this.lastUsedAt,
    required this.owner,
  });

  final String id;
  final String? name;
  final DateTime createdAt;
  final DateTime? lastUsedAt;
  final String owner;

  _EnrolledPasskey copyWith({String? name}) => _EnrolledPasskey(
    id: id,
    name: name ?? this.name,
    createdAt: createdAt,
    lastUsedAt: lastUsedAt,
    owner: owner,
  );

  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'name': name,
    'created_at': createdAt.toIso8601String(),
    'last_used_at': lastUsedAt?.toIso8601String(),
  };
}

/// A parsed, signature-verified DPoP proof (RFC 9449 §4.3).
class _DpopProof {
  const _DpopProof({
    required this.httpMethod,
    required this.httpUri,
    required this.jwtId,
    required this.accessTokenHash,
    required this.nonce,
    required this.jwkThumbprint,
  });

  final String? httpMethod;
  final String? httpUri;
  final String jwtId;
  final String? accessTokenHash;
  final String? nonce;
  final String jwkThumbprint;
}
