import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:loginflow_auth/src/core/crypto/base64_url_encoding.dart';
import 'package:loginflow_auth/src/core/crypto/pkce_pair.dart';
import 'package:loginflow_auth/src/core/crypto/sha256_hashing.dart';

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

/// A user known to the fake server.
class FakeUser {
  const FakeUser({
    required this.subject,
    required this.email,
    required this.password,
    required this.name,
    this.isTotpEnabled = false,
  });

  final String subject;
  final String email;
  final String password;
  final String name;
  final bool isTotpEnabled;
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
  static const String totpCode = '123456';
  static const String recoveryCode = 'RECOVERY-0001';
  static const String googleWebClientId = 'google-web-client.apps.example';
  static const String companyId = 'company-acme';

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

  /// Clients allowed to share one Native SSO group.
  final Set<String> ssoGroup = <String>{'app-one', 'app-two'};

  List<String> loginMethods = <String>[
    'password',
    'email_otp',
    'google',
    'microsoft',
  ];
  bool isSelfSignUpEnabled = true;
  bool isPasswordResetEnabled = true;
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

  final List<Map<String, String>> challengeRequests = <Map<String, String>>[];
  final List<Map<String, String>> tokenRequests = <Map<String, String>>[];
  final List<Map<String, String>> revocationRequests = <Map<String, String>>[];
  final List<String> deviceLogoutTokens = <String>[];
  final List<String> globalLogoutTokens = <String>[];
  final List<Uri> endSessionRequests = <Uri>[];
  final List<String> sentEmailOtps = <String>[];

  final Map<String, _ChallengeSession> _sessions =
      <String, _ChallengeSession>{};
  final Map<String, String> _pushedRequests = <String, String>{};
  final Map<String, _IssuedCode> _codes = <String, _IssuedCode>{};
  final Map<String, _RefreshRecord> _refreshTokens = <String, _RefreshRecord>{};
  final Set<String> _revokedFamilies = <String>{};
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

  bool isDeviceSessionActive(String sid) =>
      _deviceSessions[sid]?.isActive ?? false;

  Map<String, Object?> get discovery => <String, Object?>{
    'issuer': issuerText,
    'authorization_endpoint': '$issuerText/oauth2/authorize',
    'authorization_challenge_endpoint':
        '$issuerText/oauth2/authorize-challenge',
    'token_endpoint': '$issuerText/oauth2/token',
    'jwks_uri': '$issuerText/oauth2/jwks',
    'revocation_endpoint': '$issuerText/oauth2/revoke',
    'end_session_endpoint': '$issuerText/oauth2/end-session',
    'loginflow_login_options_endpoint': '$issuerText/oauth2/login-options',
    'loginflow_device_logout_endpoint': '$issuerText/oauth2/device-logout',
    'loginflow_global_logout_endpoint': '$issuerText/oauth2/logout-everywhere',
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

  /// Handles one request; both transports end here.
  Future<FakeHttpResponse> respond(FakeHttpRequest request) async {
    final form = request.method == 'POST'
        ? Uri.splitQueryString(request.body)
        : null;
    final response = FakeHttpResponse();
    response.headers['cache-control'] = 'no-store';
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
          'login_methods': loginMethods,
          'self_signup': isSelfSignUpEnabled,
          'password_reset': isPasswordResetEnabled,
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
    final _ChallengeSession session;
    if (sessionKey == null) {
      session = _ChallengeSession(key: _token32(), clientId: clientId);
      _sessions[session.key] = session;
    } else {
      final existing = _sessions[sessionKey];
      if (existing == null) {
        return _oauthError(response, 400, 'invalid_session');
      }
      session = existing;
    }
    final challenge = form['code_challenge'];
    if (challenge != null) {
      if (form['code_challenge_method'] != 'S256') {
        return _oauthError(response, 400, 'invalid_request');
      }
      session.openAuthorization(
        codeChallenge: challenge,
        nonce: form['nonce'],
        scope: form['scope'] ?? '',
        redirectUri: form['redirect_uri'],
        state: form['state'],
        acrValues: form['acr_values'],
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
    if (form['prompt'] == 'create' || form['intent'] == 'password_reset') {
      return _redirectToWeb(response, session);
    }
    final provider = form['upstream_provider'];
    if (provider == 'microsoft' ||
        (provider == 'google' && form['upstream_flow'] == 'browser')) {
      return _redirectToWeb(response, session);
    }
    if (provider == 'google') {
      final token = form['upstream_token'];
      if (token == null) {
        session.upstreamNonce = _token32();
        return _step(
          response,
          session,
          'upstream_token',
          upstream: <String, Object?>{
            'provider': 'google',
            'nonce': session.upstreamNonce,
            'client_id': googleWebClientId,
          },
        );
      }
      final parts = token.split(':');
      if (parts.length != 3 ||
          parts[0] != 'google' ||
          parts[1] != session.upstreamNonce) {
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
    final user = users[session.email];
    final password = form['password'];
    if (password != null) {
      if (user == null || user.password != password) {
        return _step(
          response,
          session,
          'password',
          stepError: 'invalid_credential',
          methods: <String>['password', 'email_otp'],
        );
      }
      session.isPrimaryAuthenticated = true;
    }
    if (form['method'] == 'email_otp' || form['resend'] == 'email_otp') {
      sentEmailOtps.add(session.email ?? '');
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
          methods: <String>['totp', 'recovery_code'],
        );
      }
      session.isSecondFactorDone = true;
    }
    const stepFields = <String>[
      'password',
      'method',
      'email_otp',
      'resend',
      'totp',
      'recovery_code',
      'upstream_provider',
    ];
    final hasStepInput = stepFields.any(form.containsKey);
    if (!session.isPrimaryAuthenticated &&
        !hasStepInput &&
        !session.isIdentifiedByHint) {
      return _step(response, session, 'select_method', methods: loginMethods);
    }
    if (!session.isPrimaryAuthenticated || user == null) {
      return _step(
        response,
        session,
        'password',
        methods: <String>['password', 'email_otp'],
      );
    }
    final needsSecondFactor =
        user.isTotpEnabled || (session.acrValues?.contains('mfa') ?? false);
    if (needsSecondFactor && !session.isSecondFactorDone) {
      return _step(
        response,
        session,
        'totp',
        methods: <String>['totp', 'recovery_code'],
      );
    }
    final code = _issueCode(session, user, redirectUri: null);
    _json(response, 200, <String, Object?>{'authorization_code': code});
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
      final code = _issueCode(session, user, redirectUri: redirect);
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
        query['code_challenge_method'] != 'S256') {
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
          )
          ..email = 'ana@example.com';
    final code = _issueCode(
      session,
      users['ana@example.com']!,
      redirectUri: redirect,
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
    final sid = 'sid_${_token32()}';
    _deviceSessions[sid] = _DeviceSession(subject: issued.user.subject);
    _issueTokens(
      response,
      clientId: clientId,
      user: issued.user,
      scope: issued.scope,
      sid: sid,
      nonce: issued.nonce,
      familyId: _token32(),
      authSession: issued.authSession,
      isDeviceSecretNeeded: true,
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
    record.isUsed = true;
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
    _issueTokens(
      response,
      clientId: clientId,
      user: record.user,
      scope: record.scope,
      sid: record.sid,
      nonce: null,
      familyId: record.familyId,
      authSession: null,
      isDeviceSecretNeeded: !_deviceSecrets.containsKey(form['device_secret']),
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
    _issueTokens(
      response,
      clientId: clientId,
      user: user,
      scope: form['scope'] ?? '',
      sid: sid,
      nonce: null,
      familyId: _token32(),
      authSession: null,
      isDeviceSecretNeeded: false,
      issuedTokenType: 'urn:ietf:params:oauth:token-type:access_token',
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
    required String? authSession,
    required bool isDeviceSecretNeeded,
    String? issuedTokenType,
  }) {
    final accessToken = 'at_${_token32()}';
    final refreshToken = 'rt_${_token32()}';
    lastIssuedRefreshToken = refreshToken;
    _accessTokens[accessToken] = _AccessRecord(subject: user.subject, sid: sid);
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
      'token_type': 'Bearer',
      'expires_in': 900,
      'refresh_token': refreshToken,
      'id_token':
          ?(omitsIdTokenOnRefresh && nonce == null && authSession == null
          ? null
          : idToken),
      'scope': scope,
      'device_secret': ?deviceSecret,
      'auth_session': ?authSession,
      'issued_token_type': ?issuedTokenType,
    });
  }

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
      'email': user.email,
      'email_verified': true,
      'name': user.name,
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
    final token = header.startsWith('Bearer ') ? header.substring(7) : '';
    final access = _accessTokens[token];
    if (access == null) {
      return _oauthError(response, 401, 'invalid_token');
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

  void _redirectToWeb(FakeHttpResponse response, _ChallengeSession session) {
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
    List<String>? methods,
    Map<String, Object?>? upstream,
  }) => _json(response, 403, <String, Object?>{
    'error': 'insufficient_authorization',
    'auth_session': session.key,
    'next': next,
    'methods': ?methods,
    'step_error': ?stepError,
    'upstream': ?upstream,
  });

  String _issueCode(
    _ChallengeSession session,
    FakeUser user, {
    required String? redirectUri,
  }) {
    final code = 'code_${_token32()}';
    _codes[code] = _IssuedCode(
      clientId: session.clientId,
      codeChallenge: session.codeChallenge ?? '',
      nonce: session.nonce,
      scope: session.scope,
      user: user,
      redirectUri: redirectUri,
      authSession: redirectUri == null ? session.key : null,
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
    response.headers['content-type'] = 'application/json';
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

  final String key;
  final String clientId;
  String? codeChallenge;
  String? nonce;
  String scope = '';
  String? redirectUri;
  String? state;
  String? acrValues;
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
  }) {
    this.codeChallenge = codeChallenge;
    this.nonce = nonce;
    this.scope = scope;
    this.redirectUri = redirectUri;
    this.state = state;
    this.acrValues = acrValues;
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
    required this.authSession,
  });

  final String clientId;
  final String codeChallenge;
  final String? nonce;
  final String scope;
  final FakeUser user;
  final String? redirectUri;
  final String? authSession;
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
  _DeviceSession({required this.subject});

  final String subject;
  bool isActive = true;
}

class _AccessRecord {
  const _AccessRecord({required this.subject, required this.sid});

  final String subject;
  final String sid;
}
