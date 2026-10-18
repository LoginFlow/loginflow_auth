import 'dart:async';

import 'package:http/http.dart' as http;
import 'package:logger_rs/logger_rs.dart';
import 'package:loginflow_auth/src/core/browser/callback_uri_matching.dart';
import 'package:loginflow_auth/src/core/browser/external_user_agent.dart';
import 'package:loginflow_auth/src/core/browser/pending_authorization.dart';
import 'package:loginflow_auth/src/core/browser/pending_authorization_store.dart';
import 'package:loginflow_auth/src/core/browser/pending_purpose.dart';
import 'package:loginflow_auth/src/core/config/login_flow_clock.dart';
import 'package:loginflow_auth/src/core/config/login_flow_config.dart';
import 'package:loginflow_auth/src/core/crypto/secure_random_source.dart';
import 'package:loginflow_auth/src/core/discovery/discovery_client.dart';
import 'package:loginflow_auth/src/core/discovery/discovery_document.dart';
import 'package:loginflow_auth/src/core/dpop/dpop_key_store.dart';
import 'package:loginflow_auth/src/core/dpop/dpop_proof_factory.dart';
import 'package:loginflow_auth/src/core/error/authorization_response_problem.dart';
import 'package:loginflow_auth/src/core/error/browser_failure_reason.dart';
import 'package:loginflow_auth/src/core/error/id_token_failure.dart';
import 'package:loginflow_auth/src/core/error/login_flow_error.dart';
import 'package:loginflow_auth/src/core/error/passkey_failure_reason.dart';
import 'package:loginflow_auth/src/core/error/upstream_failure_reason.dart';
import 'package:loginflow_auth/src/core/flow/active_session.dart';
import 'package:loginflow_auth/src/core/flow/authorization_attempt.dart';
import 'package:loginflow_auth/src/core/flow/flow_origin.dart';
import 'package:loginflow_auth/src/core/http/login_flow_transport.dart';
import 'package:loginflow_auth/src/core/http/resource_authorization.dart';
import 'package:loginflow_auth/src/core/http/transport_reply.dart';
import 'package:loginflow_auth/src/core/id_token/id_token_claims.dart';
import 'package:loginflow_auth/src/core/id_token/id_token_expectations.dart';
import 'package:loginflow_auth/src/core/id_token/id_token_validator.dart';
import 'package:loginflow_auth/src/core/jose/compact_jws.dart';
import 'package:loginflow_auth/src/core/jose/jwks_cache.dart';
import 'package:loginflow_auth/src/core/protocol/browser/authorization_callback.dart';
import 'package:loginflow_auth/src/core/protocol/browser/authorization_prompt.dart';
import 'package:loginflow_auth/src/core/protocol/browser/authorization_request.dart';
import 'package:loginflow_auth/src/core/protocol/browser/end_session_request.dart';
import 'package:loginflow_auth/src/core/protocol/challenge/authorization_challenge_client.dart';
import 'package:loginflow_auth/src/core/protocol/challenge/challenge_input.dart';
import 'package:loginflow_auth/src/core/protocol/challenge/challenge_request.dart';
import 'package:loginflow_auth/src/core/protocol/challenge/challenge_response.dart';
import 'package:loginflow_auth/src/core/protocol/challenge/challenge_step.dart';
import 'package:loginflow_auth/src/core/protocol/challenge/upstream_flow.dart';
import 'package:loginflow_auth/src/core/protocol/challenge/upstream_prompt.dart';
import 'package:loginflow_auth/src/core/protocol/challenge/upstream_provider.dart';
import 'package:loginflow_auth/src/core/protocol/challenge/upstream_token_type.dart';
import 'package:loginflow_auth/src/core/protocol/login_options/client_login_options.dart';
import 'package:loginflow_auth/src/core/protocol/login_options/login_options_client.dart';
import 'package:loginflow_auth/src/core/protocol/logout/revocation_client.dart';
import 'package:loginflow_auth/src/core/protocol/logout/session_logout_client.dart';
import 'package:loginflow_auth/src/core/protocol/passkeys/passkey_account_client.dart';
import 'package:loginflow_auth/src/core/protocol/passkeys/passkey_credential.dart';
import 'package:loginflow_auth/src/core/protocol/step_up/step_up_requirement.dart';
import 'package:loginflow_auth/src/core/protocol/token/token_client.dart';
import 'package:loginflow_auth/src/core/protocol/token/token_grant.dart';
import 'package:loginflow_auth/src/core/protocol/token/token_response.dart';
import 'package:loginflow_auth/src/core/session/user_identity.dart';
import 'package:loginflow_auth/src/core/sso/sso_candidate.dart';
import 'package:loginflow_auth/src/core/sso/sso_entry.dart';
import 'package:loginflow_auth/src/core/sso/sso_store.dart';
import 'package:loginflow_auth/src/core/state/auth_state.dart';
import 'package:loginflow_auth/src/core/state/challenge_prompt.dart';
import 'package:loginflow_auth/src/core/state/challenge_purpose.dart';
import 'package:loginflow_auth/src/core/state/sign_out_reason.dart';
import 'package:loginflow_auth/src/core/state/sign_out_scope.dart';
import 'package:loginflow_auth/src/core/storage/session_store.dart';
import 'package:loginflow_auth/src/core/storage/stored_session.dart';
import 'package:loginflow_auth/src/core/upstream/google_id_token_source.dart';
import 'package:loginflow_auth/src/core/upstream/upstream_token_source.dart';
import 'package:loginflow_auth/src/core/webauthn/passkey_authenticator.dart';
import 'package:result_controller/result_controller.dart';

/// The LoginFlow client: native first-party sign-in
/// (draft-ietf-oauth-first-party-apps-04), browser fallback (RFC 8252),
/// ID token validation, token lifecycle, OpenID Connect Native SSO and the
/// four logout levels.
///
/// Plain Dart with a [states] stream: it imposes no state-management
/// framework on the app. Every operation returns `Result<T, LoginFlowError>`;
/// expected failures never throw.
class LoginFlowAuth {
  LoginFlowAuth({
    required this.config,
    required http.Client httpClient,
    required this._sessionStore,
    required PendingAuthorizationStore pendingAuthorizationStore,
    this._ssoStore,
    this._userAgent,
    this._googleIdTokenSource,
    this._appleTokenSource,
    this._facebookTokenSource,
    this._passkeyAuthenticator,
    DpopKeyStore? dpopKeyStore,
    LoginFlowClock clock = const SystemLoginFlowClock(),
    this._randomSource = const PlatformSecureRandomSource(),
  }) : _pendingStore = pendingAuthorizationStore,
       _clock = clock {
    _dpop = config.enableDpop && dpopKeyStore != null
        ? DpopProofFactory(
            keyStore: dpopKeyStore,
            randomSource: _randomSource,
            clock: clock,
          )
        : null;
    final transport = LoginFlowTransport(
      client: httpClient,
      timeout: config.requestTimeout,
      dpop: _dpop,
    );
    _transport = transport;
    _discovery = DiscoveryClient(
      issuer: config.issuer,
      transport: transport,
      clock: clock,
    );
    _idTokens = IdTokenValidator(
      jwks: JwksCache(transport: transport, clock: clock),
      clock: clock,
      clockSkew: config.clockSkew,
    );
    _challenge = AuthorizationChallengeClient(transport: transport);
    _tokens = TokenClient(transport: transport, clientId: config.clientId);
    _revocation = RevocationClient(
      transport: transport,
      clientId: config.clientId,
    );
    _sessionLogout = SessionLogoutClient(
      transport: transport,
      clientId: config.clientId,
    );
    _loginOptions = LoginOptionsClient(
      transport: transport,
      clientId: config.clientId,
    );
    _passkeyAccount = PasskeyAccountClient(
      transport: transport,
      issuer: config.issuer,
    );
  }

  final LoginFlowConfig config;
  final SessionStore _sessionStore;
  final PendingAuthorizationStore _pendingStore;
  final SsoStore? _ssoStore;
  final ExternalUserAgent? _userAgent;
  final GoogleIdTokenSource? _googleIdTokenSource;
  final UpstreamTokenSource? _appleTokenSource;
  final UpstreamTokenSource? _facebookTokenSource;
  final PasskeyAuthenticator? _passkeyAuthenticator;
  final LoginFlowClock _clock;
  final SecureRandomSource _randomSource;

  /// One source per provider the app configured, keyed by the wire name the
  /// server uses (`upstream_provider`). [GoogleIdTokenSource] keeps its own
  /// narrower interface for backward compatibility; it is wrapped here so
  /// [_answerUpstream] handles every provider the same way, with no
  /// per-provider branch.
  late final Map<UpstreamProvider, UpstreamTokenSource> _upstreamSources =
      <UpstreamProvider, UpstreamTokenSource>{
        UpstreamProvider.google: ?_wrappedGoogleSource,
        UpstreamProvider.apple: ?_appleTokenSource,
        UpstreamProvider.facebook: ?_facebookTokenSource,
      };

  UpstreamTokenSource? get _wrappedGoogleSource {
    final source = _googleIdTokenSource;
    return source == null ? null : _GoogleUpstreamTokenSourceAdapter(source);
  }

  /// The registered, platform-available native source for [provider], or
  /// `null` when the app opens this provider through the hosted page
  /// instead (not configured, or available only through
  /// `redirect_to_web` on this platform — e.g. Apple on Android).
  UpstreamTokenSource? _nativeSourceFor(UpstreamProvider provider) {
    final source = _upstreamSources[provider];
    return source != null && source.isAvailable ? source : null;
  }

  late final DpopProofFactory? _dpop;
  late final LoginFlowTransport _transport;
  late final DiscoveryClient _discovery;
  late final IdTokenValidator _idTokens;
  late final AuthorizationChallengeClient _challenge;
  late final TokenClient _tokens;
  late final RevocationClient _revocation;
  late final SessionLogoutClient _sessionLogout;
  late final LoginOptionsClient _loginOptions;
  late final PasskeyAccountClient _passkeyAccount;

  final StreamController<AuthState> _states =
      StreamController<AuthState>.broadcast();

  AuthState _state = const AuthInitializing();
  AuthorizationAttempt? _attempt;
  ActiveSession? _session;
  Future<Result<String, LoginFlowError>>? _refreshing;

  /// Bumped whenever the session ends or is replaced. A refresh that
  /// completes under another generation belongs to a session that no longer
  /// exists and is discarded (`doc/decisions.md` D9).
  int _generation = 0;

  /// The current state.
  AuthState get state => _state;

  /// Every state transition, in order.
  Stream<AuthState> get states => _states.stream;

  /// Reads the stored session and, when nobody is signed in, looks for a
  /// Native SSO session of a sibling app. Pass the launch URI on the web so a
  /// browser callback is completed.
  Future<Result<AuthState, LoginFlowError>> initialize({Uri? launchUri}) async {
    if (config.validate() case Err(:final error)) {
      Log.e(error.message);
      _emit(const SignedOut());
      return Err(error);
    }
    final storedResult = await _sessionStore.read();
    if (storedResult case Err(:final error)) {
      Log.e('Reading the stored session failed: ${error.message}');
      _emit(const SignedOut());
      return Err(error);
    }
    final stored = storedResult.data;
    if (stored != null) {
      await _restore(stored);
    }
    if (launchUri != null && isBrowserCallback(launchUri)) {
      return completeBrowserRedirect(launchUri);
    }
    if (_session != null) {
      return Ok(_state);
    }
    final candidate = await _ssoCandidate();
    if (candidate != null) {
      return Ok(_emit(SsoAvailable(candidate: candidate)));
    }
    // A stored session that could not be restored already reported why
    // (e.g. `sessionRevoked` when its DPoP key is gone); keep that reason.
    final current = _state;
    return Ok(_emit(current is SignedOut ? current : const SignedOut()));
  }

  /// The login methods, sign-up and password-reset switches the server
  /// enables for this client.
  Future<Result<ClientLoginOptions, LoginFlowError>> fetchLoginOptions() async {
    final discoveryResult = await _discovery.load();
    if (discoveryResult case Err(:final error)) {
      return Err(error);
    }
    final endpoint = discoveryResult.data.loginOptionsEndpoint;
    if (endpoint == null) {
      return Err(
        const UnsupportedByServer(feature: 'loginflow_login_options_endpoint'),
      );
    }
    return _loginOptions.fetch(endpoint);
  }

  /// Opens a sign-in without choosing a method: the server answers
  /// `next: select_method` with the client's primary methods
  /// (`doc/server-contract.md` §5.5); continue with [selectMethod].
  Future<Result<AuthState, LoginFlowError>> beginSignIn({String? loginHint}) =>
      _startAttempt(
        purpose: ChallengePurpose.signIn,
        loginHint: loginHint,
        input: loginHint == null ? null : LoginHintInput(loginHint: loginHint),
      );

  /// Identifier and password in one request.
  Future<Result<AuthState, LoginFlowError>> signInWithPassword({
    required String loginHint,
    required String password,
  }) => _startAttempt(
    purpose: ChallengePurpose.signIn,
    loginHint: loginHint,
    input: PasswordSignInInput(loginHint: loginHint, password: password),
  );

  /// Asks the server to email a one-time code to [loginHint].
  Future<Result<AuthState, LoginFlowError>> requestEmailOtp({
    required String loginHint,
  }) => _startAttempt(
    purpose: ChallengePurpose.signIn,
    loginHint: loginHint,
    input: IdentifierInput(
      loginHint: loginHint,
      method: ChallengeStep.emailOtp,
    ),
  );

  Future<Result<AuthState, LoginFlowError>> submitEmailOtp(String code) =>
      _continueAttempt(EmailOtpInput(code: code));

  Future<Result<AuthState, LoginFlowError>> resendEmailOtp() =>
      _continueAttempt(const ResendEmailOtpInput());

  /// The `email_otp` step's "email me a sign-in link instead" action
  /// (contract: magic link). Only meaningful when
  /// `ClientLoginOptions.isMagicLinkOffered`; the server still answers
  /// `next: email_otp` either way, so the code on the same step keeps
  /// working.
  Future<Result<AuthState, LoginFlowError>> requestMagicLink() =>
      _continueAttempt(const RequestMagicLinkInput());

  /// Exchanges a magic-link token this app intercepted from its own
  /// `https://<company host>/login/magic/<client_id>?token=...` Android
  /// App Link / iOS Universal Link (contract: magic link §3) — the
  /// `auth_session` carried by the CURRENT attempt must be the same one
  /// that requested the link, exactly like [resendEmailOtp]/
  /// [submitEmailOtp] continue an already-open attempt.
  Future<Result<AuthState, LoginFlowError>> submitMagicLinkToken(
    String token,
  ) => _continueAttempt(MagicLinkTokenInput(token: token));

  /// The `token` query parameter of a magic-link URL addressed to this app
  /// (`https://<company host>/login/magic/<client_id>?token=...` with
  /// `<client_id>` equal to [LoginFlowConfig.clientId]), or `null` for any
  /// other URI — the consuming app's deep-link listener (Android App Links /
  /// iOS Universal Links, e.g. the `app_links` package) calls this first and
  /// only calls [submitMagicLinkToken] with a non-null result. The host
  /// itself is verified by the operating system (App Links / Universal Links
  /// only deliver verified domains).
  String? magicLinkTokenFromUri(Uri uri) {
    final segments = uri.pathSegments;
    final isThisAppsMagicLink =
        uri.scheme == 'https' &&
        segments.length == 3 &&
        segments[0] == 'login' &&
        segments[1] == 'magic' &&
        segments[2] == config.clientId;
    if (!isThisAppsMagicLink) {
      return null;
    }
    final token = uri.queryParameters['token'];
    return token == null || token.isEmpty ? null : token;
  }

  Future<Result<AuthState, LoginFlowError>> submitPassword(String password) =>
      _continueAttempt(PasswordInput(password: password));

  Future<Result<AuthState, LoginFlowError>> submitTotp(String code) =>
      _continueAttempt(TotpInput(code: code));

  Future<Result<AuthState, LoginFlowError>> submitRecoveryCode(String code) =>
      _continueAttempt(RecoveryCodeInput(code: code));

  /// Chooses one of the alternatives of the current prompt.
  Future<Result<AuthState, LoginFlowError>> selectMethod(
    ChallengeStep method,
  ) => _continueAttempt(MethodSelectionInput(method: method));

  /// Passkey (WebAuthn L3) sign-in: targeted when [loginHint] is given,
  /// discoverable/conditional otherwise. The platform ceremony
  /// ([PasskeyAuthenticator.getAssertion]) runs automatically once the
  /// server answers with its options — same shape as [signInWithGoogle],
  /// never surfaced as a [ChallengeRequired] state.
  Future<Result<AuthState, LoginFlowError>> signInWithPasskey({
    String? loginHint,
  }) => _startAttempt(
    purpose: ChallengePurpose.signIn,
    loginHint: loginHint,
    input: loginHint == null
        ? const MethodSelectionInput(method: ChallengeStep.webauthnIdentify)
        : IdentifierInput(
            loginHint: loginHint,
            method: ChallengeStep.webauthnIdentify,
          ),
  );

  /// Identifier plus an admin-issued, single-use Temporary Access Pass in
  /// one request: satisfies both the primary method and the second factor
  /// in one step (`doc/server-contract.md` passkeys section). The server
  /// never prompts for this method — an app offers it as its own entry
  /// point (e.g. "I have a temporary access pass"), not as a reaction to a
  /// challenge response.
  Future<Result<AuthState, LoginFlowError>> signInWithTemporaryAccessPass({
    required String loginHint,
    required String code,
  }) => _startAttempt(
    purpose: ChallengePurpose.signIn,
    loginHint: loginHint,
    input: TemporaryAccessPassSignInInput(loginHint: loginHint, code: code),
  );

  /// Continues an attempt whose identity is already bound to the
  /// `auth_session` (step-up/reauthentication) with just the code.
  Future<Result<AuthState, LoginFlowError>> submitTemporaryAccessPass(
    String code,
  ) => _continueAttempt(TemporaryAccessPassInput(code: code));

  /// Google natively when a [GoogleIdTokenSource] is configured, otherwise in
  /// the system browser.
  Future<Result<AuthState, LoginFlowError>> signInWithGoogle() => _startAttempt(
    purpose: ChallengePurpose.signIn,
    input: UpstreamStartInput(
      provider: UpstreamProvider.google,
      flow: _googleIdTokenSource == null
          ? UpstreamFlow.browser
          : UpstreamFlow.native,
    ),
  );

  /// Microsoft always runs in the system browser (`doc/decisions.md` D4).
  Future<Result<AuthState, LoginFlowError>> signInWithMicrosoft() =>
      _startAttempt(
        purpose: ChallengePurpose.signIn,
        input: const UpstreamStartInput(
          provider: UpstreamProvider.microsoft,
          flow: UpstreamFlow.browser,
        ),
      );

  /// Apple natively on iOS/macOS when an [UpstreamTokenSource] is
  /// configured for [UpstreamProvider.apple] and available on this
  /// platform; the hosted page in the system browser otherwise — including
  /// Android, where the native `sign_in_with_apple` ceremony is
  /// deliberately not used (`doc/decisions.md`).
  Future<Result<AuthState, LoginFlowError>> signInWithApple() => _startAttempt(
    purpose: ChallengePurpose.signIn,
    input: UpstreamStartInput(
      provider: UpstreamProvider.apple,
      flow: _nativeSourceFor(UpstreamProvider.apple) == null
          ? UpstreamFlow.browser
          : UpstreamFlow.native,
    ),
  );

  /// Facebook natively (Limited Login on iOS, classic login on Android)
  /// when an [UpstreamTokenSource] is configured for
  /// [UpstreamProvider.facebook], otherwise the hosted page in the system
  /// browser.
  Future<Result<AuthState, LoginFlowError>> signInWithFacebook() =>
      _startAttempt(
        purpose: ChallengePurpose.signIn,
        input: UpstreamStartInput(
          provider: UpstreamProvider.facebook,
          flow: _nativeSourceFor(UpstreamProvider.facebook) == null
              ? UpstreamFlow.browser
              : UpstreamFlow.native,
        ),
      );

  /// Self sign-up (`prompt=create`); the server continues in the browser.
  Future<Result<AuthState, LoginFlowError>> signUp() => _startAttempt(
    purpose: ChallengePurpose.signIn,
    prompt: AuthorizationPrompt.create.wireName,
  );

  /// Password reset on the hosted pages (first-party-apps App. A.2).
  Future<Result<AuthState, LoginFlowError>> resetPassword({
    String? loginHint,
  }) => _startAttempt(
    purpose: ChallengePurpose.signIn,
    loginHint: loginHint,
    input: PasswordResetInput(loginHint: loginHint),
  );

  /// Authorization code + PKCE through the system browser. On the web this
  /// is a top-level redirect: try [AuthorizationPrompt.none] first and fall
  /// back to an interactive request on `SignOutReason.loginRequired`.
  Future<Result<AuthState, LoginFlowError>> signInWithBrowser({
    AuthorizationPrompt? prompt,
    String? loginHint,
  }) async {
    final discoveryResult = await _discovery.load();
    if (discoveryResult case Err(:final error)) {
      return Err(error);
    }
    final discovery = discoveryResult.data;
    final attempt = AuthorizationAttempt.start(
      purpose: ChallengePurpose.signIn,
      randomSource: _randomSource,
      loginHint: loginHint,
      prompt: prompt?.wireName,
    );
    _attempt = attempt;
    return _openAuthorization(discovery, attempt, requestUri: null);
  }

  /// Whether [uri] is a redirect back to this client with a response.
  bool isBrowserCallback(Uri uri) {
    final redirects = <Uri?>[config.redirectUri, config.postLogoutRedirectUri];
    return uri.queryParameters.containsKey('state') &&
        redirects.nonNulls.any(uri.targets);
  }

  /// How long a browser round-trip may stay pending (`doc/decisions.md`
  /// D17).
  static const Duration pendingLifetime = Duration(minutes: 10);

  /// Completes a browser round-trip from its callback [uri].
  ///
  /// A callback that does not target the pending redirect URI with the
  /// pending `state` is ignored: it is logged, the pending request is kept
  /// and the state does not change, so a forged navigation cannot abort a
  /// legitimate sign-in.
  Future<Result<AuthState, LoginFlowError>> completeBrowserRedirect(
    Uri uri,
  ) async {
    final pendingResult = await _readPending();
    if (pendingResult case Err(:final error)) {
      return Err(error);
    }
    final pending = pendingResult.data;
    if (!_matches(uri, pending)) {
      Log.w('Ignoring a callback that does not match the pending request.');
      return Err(
        const AuthorizationResponseRejected(
          problem: AuthorizationResponseProblem.stateMismatch,
        ),
      );
    }
    return _completeMatched(uri, pending);
  }

  /// The pending request, unless it is missing or expired.
  Future<Result<PendingAuthorization, LoginFlowError>> _readPending() async {
    final pendingResult = await _pendingStore.read();
    if (pendingResult case Err(:final error)) {
      return Err(error);
    }
    final pending = pendingResult.data;
    if (pending == null) {
      return Err(
        const AuthorizationResponseRejected(
          problem: AuthorizationResponseProblem.noPendingRequest,
        ),
      );
    }
    if (_clock.now().difference(pending.createdAt) > pendingLifetime) {
      await _clearPending();
      _attempt = null;
      _emit(_restingState());
      return Err(
        const AuthorizationResponseRejected(
          problem: AuthorizationResponseProblem.requestExpired,
        ),
      );
    }
    return Ok(pending);
  }

  bool _matches(Uri uri, PendingAuthorization pending) =>
      uri.targets(pending.redirectUri) &&
      AuthorizationCallback.fromUri(uri).state == pending.state;

  Future<Result<AuthState, LoginFlowError>> _completeMatched(
    Uri uri,
    PendingAuthorization pending,
  ) async {
    final origin = _captureOrigin(
      isStepUp: pending.purpose == PendingPurpose.stepUp,
    );
    await _clearPending();
    await _userAgent?.discardCallback(uri.withoutResponseParameters());
    final callback = AuthorizationCallback.fromUri(uri);
    if (pending.purpose == PendingPurpose.signOut) {
      return Ok(_emit(const SignedOut(reason: SignOutReason.userRequested)));
    }
    final discoveryResult = await _discovery.load();
    if (discoveryResult case Err(:final error)) {
      return _abandon(error);
    }
    final discovery = discoveryResult.data;
    if (callback.issuer != discovery.issuer) {
      return _abandon(
        const AuthorizationResponseRejected(
          problem: AuthorizationResponseProblem.issuerMismatch,
        ),
      );
    }
    final error = callback.error;
    if (error != null) {
      if (callback.requiresInteraction && _session == null) {
        _attempt = null;
        return Ok(_emit(const SignedOut(reason: SignOutReason.loginRequired)));
      }
      return _abandon(
        AuthorizationDenied(
          code: error,
          description: callback.errorDescription,
        ),
      );
    }
    final code = callback.code;
    final verifier = pending.codeVerifier;
    if (code == null || verifier == null) {
      return _abandon(
        const AuthorizationResponseRejected(
          problem: AuthorizationResponseProblem.missingCode,
        ),
      );
    }
    return _redeemCode(
      discovery,
      code: code,
      codeVerifier: verifier,
      nonce: pending.nonce,
      redirectUri: pending.redirectUri,
      isBrowserUsed: true,
      origin: origin,
    );
  }

  /// Re-authenticates the signed-in user for [requirement] (RFC 9470,
  /// first-party-apps §7), typically a TOTP prompt.
  Future<Result<AuthState, LoginFlowError>> stepUp(
    StepUpRequirement requirement,
  ) async {
    final session = _session;
    if (session == null) {
      return Err(const NotSignedIn());
    }
    final authSession = session.stored.authSession;
    return _startAttempt(
      purpose: ChallengePurpose.stepUp,
      authSession: authSession,
      acrValues: requirement.acrValues,
      maxAge: requirement.maxAge,
      idTokenHint: authSession == null ? session.stored.idToken : null,
    );
  }

  /// Abandons the challenge in progress.
  Future<Result<AuthState, LoginFlowError>> cancelChallenge() async {
    _attempt = null;
    await _clearPending();
    return Ok(_emit(_restingState()));
  }

  /// Signs in with the shared Native SSO session (OpenID Connect Native SSO
  /// §4, RFC 8693).
  Future<Result<AuthState, LoginFlowError>> continueWithSso() async {
    final origin = _captureOrigin(isStepUp: false);
    final entry = await _readSsoEntry();
    if (entry == null) {
      return Ok(_emit(const SignedOut(reason: SignOutReason.ssoUnavailable)));
    }
    final discoveryResult = await _discovery.load();
    if (discoveryResult case Err(:final error)) {
      return Err(error);
    }
    final discovery = discoveryResult.data;
    if (!discovery.supportsTokenExchange) {
      return Err(
        const UnsupportedByServer(
          feature: DiscoveryDocument.tokenExchangeGrant,
        ),
      );
    }
    final response = await _tokens.request(
      discovery.tokenEndpoint,
      NativeSsoExchangeGrant(
        idToken: entry.idToken,
        deviceSecret: entry.deviceSecret,
        audience: discovery.issuer,
        scope: _scopeFor(discovery),
      ),
    );
    if (response case Err(:final error)) {
      return _ssoExchangeFailed(error, entry, origin);
    }
    return _acceptTokens(
      discovery,
      response.data,
      expectations: IdTokenExpectations.forClient(clientId: config.clientId),
      isBrowserUsed: false,
      isSsoBound: true,
      origin: origin,
    );
  }

  /// The user chose another account instead of the Native SSO one.
  Future<Result<AuthState, LoginFlowError>> declineSso() async =>
      Ok(_emit(const SignedOut()));

  /// Signs out locally when another app ended the device session. Call it
  /// when the app resumes (`doc/decisions.md` D14).
  Future<Result<AuthState, LoginFlowError>> verifyDeviceSession() async {
    final session = _session;
    final store = _ssoStore;
    if (session == null || store == null || !session.stored.isSsoBound) {
      return Ok(_state);
    }
    final entry = await store.read(config.issuer.toString());
    if (entry case Err(:final error)) {
      return Err(error);
    }
    if (entry.data == null) {
      await _endLocalSession(SignOutReason.deviceSessionEnded);
    }
    return Ok(_state);
  }

  /// A valid access token, refreshed when needed. Concurrent callers share
  /// one refresh, so a rotated refresh token is never presented twice
  /// (RFC 9700 §4.14.2).
  Future<Result<String, LoginFlowError>> accessToken() async {
    final session = _session;
    if (session == null) {
      return Err(const NotSignedIn());
    }
    final fresh = session.freshAccessToken(_clock.now());
    if (fresh != null) {
      return Ok(fresh);
    }
    return _refreshing ?? _startRefresh();
  }

  /// Enrolls a new passkey for the signed-in user: starts the ceremony,
  /// runs it on the platform ([PasskeyAuthenticator.createCredential]) and
  /// submits the result (`POST /v1/user/passkeys/enroll/{start,finish}`).
  /// The server requires a recently authenticated access token (RFC 9470).
  Future<Result<PasskeyCredential, LoginFlowError>> enrollPasskey({
    required String username,
    required String displayName,
    String? name,
  }) async {
    final authenticator = _passkeyAuthenticator;
    if (authenticator == null) {
      return Err(
        const PasskeyFailed(reason: PasskeyFailureReason.notConfigured),
      );
    }
    final tokenResult = await accessToken();
    if (tokenResult case Err(:final error)) {
      return Err(error);
    }
    final bearerToken = tokenResult.data;
    final startResult = await _passkeyAccount.startEnroll(
      bearerToken: bearerToken,
      username: username,
      displayName: displayName,
    );
    if (startResult case Err(:final error)) {
      return Err(error);
    }
    final created = await authenticator.createCredential(
      options: startResult.data,
    );
    if (created case Err(:final error)) {
      return Err(error);
    }
    return _passkeyAccount.finishEnroll(
      bearerToken: bearerToken,
      credential: created.data,
      name: name,
    );
  }

  /// `GET /v1/user/passkeys`.
  Future<Result<List<PasskeyCredential>, LoginFlowError>> listPasskeys() async {
    final tokenResult = await accessToken();
    if (tokenResult case Err(:final error)) {
      return Err(error);
    }
    return _passkeyAccount.list(bearerToken: tokenResult.data);
  }

  /// `PATCH /v1/user/passkeys/{id}`.
  Future<Result<PasskeyCredential, LoginFlowError>> renamePasskey({
    required String id,
    required String name,
  }) async {
    final tokenResult = await accessToken();
    if (tokenResult case Err(:final error)) {
      return Err(error);
    }
    return _passkeyAccount.rename(
      bearerToken: tokenResult.data,
      id: id,
      name: name,
    );
  }

  /// `DELETE /v1/user/passkeys/{id}`.
  Future<Result<void, LoginFlowError>> deletePasskey(String id) async {
    final tokenResult = await accessToken();
    if (tokenResult case Err(:final error)) {
      return Err(error);
    }
    return _passkeyAccount.delete(bearerToken: tokenResult.data, id: id);
  }

  /// The `Authorization` and `DPoP` headers for ONE request of the app to
  /// its own API (or to LoginFlow's `/v1/*` REST scopes) with the current
  /// access token, refreshed when needed — the same headers the library
  /// sends on its own resource requests:
  ///
  /// - with DPoP: `Authorization: DPoP <token>` plus a proof whose `htm` is
  ///   [method], `htu` is [uri] without query and fragment, `ath` hashes the
  ///   token and `nonce` is the last `DPoP-Nonce` that server sent
  ///   (RFC 9449 §4.2, §7.1, §8);
  /// - without DPoP: `Authorization: Bearer <token>`.
  ///
  /// [method] is the exact HTTP method of the request (`GET`, `POST`, ...).
  /// A proof is single use: call this again for every request, a retry
  /// included. Report every response to [shouldRetryResourceRequest].
  Future<Result<ResourceAuthorization, LoginFlowError>>
  authorizeResourceRequest({required String method, required Uri uri}) async {
    final tokenResult = await accessToken();
    if (tokenResult case Err(:final error)) {
      return Err(error);
    }
    return _transport.authorize(
      httpMethod: method,
      uri: uri,
      accessToken: tokenResult.data,
    );
  }

  /// Reports the response to a request authorized with
  /// [authorizeResourceRequest]: caches its `DPoP-Nonce` (the header, when
  /// present) for the next proof to that server, and returns `true` when the
  /// server refused the request for a missing or stale nonce (`401` with
  /// `WWW-Authenticate: DPoP error="use_dpop_nonce"`, RFC 9449 §9). Then send
  /// the request once more with a NEW [authorizeResourceRequest]; never
  /// retry a second time for the same request. Always `false` without DPoP.
  bool shouldRetryResourceRequest({
    required Uri uri,
    required int statusCode,
    String? dpopNonce,
    String? wwwAuthenticate,
  }) => _transport.acceptReply(
    uri,
    TransportReply(
      statusCode: statusCode,
      body: '',
      dpopNonce: dpopNonce,
      wwwAuthenticate: wwwAuthenticate,
    ),
  );

  Future<Result<AuthState, LoginFlowError>> signOut(SignOutScope scope) =>
      switch (scope) {
        SignOutScope.app => _signOutApp(),
        SignOutScope.device => _signOutServerSessions(
          (discovery) => discovery.deviceLogoutEndpoint,
          'loginflow_device_logout_endpoint',
        ),
        SignOutScope.everywhere => _signOutServerSessions(
          (discovery) => discovery.globalLogoutEndpoint,
          'loginflow_global_logout_endpoint',
        ),
        SignOutScope.browser => _signOutBrowser(),
      };

  Future<void> dispose() => _states.close();

  Future<void> _restore(StoredSession stored) async {
    final claims = _readStoredClaims(stored.idToken);
    if (claims == null) {
      Log.w('The stored ID token is unreadable; clearing the session.');
      await _endLocalSession(SignOutReason.none);
      return;
    }
    final session = ActiveSession(
      stored: stored,
      identity: UserIdentity.fromClaims(claims),
    );
    _session = session;
    final store = _ssoStore;
    if (stored.isSsoBound && store != null) {
      final entry = await store.read(config.issuer.toString());
      if (entry case Ok(data: null)) {
        await _endLocalSession(SignOutReason.deviceSessionEnded);
        return;
      }
    }
    final boundKey = stored.dpopJkt;
    if (boundKey != null) {
      await _resumeKeyBoundSession(boundKey);
      return;
    }
    _emit(SignedIn(session: session.toPublic()));
  }

  /// A DPoP-bound session is only as good as the key it is bound to, and a
  /// browser can drop that key (cleared site data, private browsing) while
  /// keeping the stored refresh token. The key is checked locally first,
  /// then the session is refreshed with it before it is reported signed in,
  /// so a refused refresh (`invalid_grant`, e.g. the 24 h web lifetime)
  /// signs out at start-up instead of on the app's first API call.
  Future<void> _resumeKeyBoundSession(String boundKey) async {
    if (!await _holdsKey(boundKey)) {
      Log.w('The DPoP key of the stored session is gone; signing out.');
      await _endLocalSession(SignOutReason.sessionRevoked);
      return;
    }
    final refreshed = await _startRefresh();
    if (refreshed case Err(:final error)) {
      Log.w('Refreshing the restored session failed: ${error.message}');
    }
    final session = _session;
    if (session != null && _state is! SignedIn && _attempt == null) {
      _emit(SignedIn(session: session.toPublic()));
    }
  }

  /// Whether the platform still holds the DPoP key with thumbprint
  /// [boundKey].
  Future<bool> _holdsKey(String boundKey) async {
    final dpop = _dpop;
    if (dpop == null) {
      return false;
    }
    final thumbprint = await dpop.keyThumbprint();
    return thumbprint.when(
      ok: (current) => current == boundKey,
      err: (error) {
        Log.w('Reading the DPoP key failed: ${error.message}');
        return false;
      },
    );
  }

  /// The thumbprint of the DPoP key a `DPoP` token response was bound to,
  /// or `null` for a Bearer response.
  Future<String?> _boundKeyOf(TokenResponse response) async {
    final dpop = _dpop;
    if (dpop == null || !response.isDpop) {
      return null;
    }
    final thumbprint = await dpop.keyThumbprint();
    return thumbprint.when(
      ok: (value) => value,
      err: (error) {
        Log.w('The DPoP key thumbprint is unavailable: ${error.message}');
        return null;
      },
    );
  }

  /// Claims of an ID token this library validated before storing it.
  IdTokenClaims? _readStoredClaims(String idToken) =>
      CompactJws.parse(idToken).when(
        ok: (jws) {
          try {
            return IdTokenClaims.fromJson(jws.claims);
          } on FormatException {
            return null;
          }
        },
        err: (_) => null,
      );

  Future<Result<AuthState, LoginFlowError>> _startAttempt({
    required ChallengePurpose purpose,
    ChallengeInput? input,
    String? loginHint,
    String? prompt,
    String? authSession,
    List<String> acrValues = const <String>[],
    Duration? maxAge,
    String? idTokenHint,
  }) async {
    _attempt = AuthorizationAttempt.start(
      purpose: purpose,
      randomSource: _randomSource,
      authSession: authSession,
      loginHint: loginHint,
      prompt: prompt,
      acrValues: acrValues,
      maxAge: maxAge,
      idTokenHint: idTokenHint,
    );
    return _continueAttempt(input);
  }

  Future<Result<AuthState, LoginFlowError>> _continueAttempt(
    ChallengeInput? input,
  ) async {
    final attempt = _attempt;
    if (attempt == null) {
      return Err(const NoChallengeInProgress());
    }
    final origin = _captureOrigin(
      isStepUp: attempt.purpose == ChallengePurpose.stepUp,
    );
    final discoveryResult = await _discovery.load();
    if (discoveryResult case Err(:final error)) {
      return Err(error);
    }
    if (!_isCurrentOrigin(origin)) {
      return Err(const NoChallengeInProgress());
    }
    final discovery = discoveryResult.data;
    final endpoint = discovery.authorizationChallengeEndpoint;
    if (endpoint == null) {
      return Err(
        const UnsupportedByServer(feature: 'authorization_challenge_endpoint'),
      );
    }
    final request = ChallengeRequest(
      clientId: config.clientId,
      authSession: attempt.authSession,
      authorization: attempt.isAuthorizationSent
          ? null
          : attempt.toParameters(
              scope: _scopeFor(discovery),
              redirectUri: config.redirectUri,
              uiLocales: config.uiLocales,
            ),
      input: input,
    );
    final response = await _challenge.send(endpoint, request);
    if (!_isCurrentOrigin(origin)) {
      Log.w('Ignoring a challenge response for an attempt that ended.');
      return Err(const NoChallengeInProgress());
    }
    if (response case Err(:final error)) {
      return Err(error);
    }
    final sent = attempt.copyWith(isAuthorizationSent: true);
    _attempt = sent;
    return switch (response.data) {
      final ChallengeStepRequired step => _onStepRequired(sent, step),
      final ChallengeCodeIssued issued => _redeemCode(
        discovery,
        code: issued.authorizationCode,
        codeVerifier: attempt.pkce.codeVerifier,
        nonce: attempt.nonce,
        redirectUri: null,
        isBrowserUsed: false,
        origin: origin.withAttempt(sent),
      ),
      final ChallengeRedirectToWeb redirect => _onRedirectToWeb(
        discovery,
        sent,
        redirect,
      ),
      ChallengeSessionInvalid() => _onSessionInvalid(sent),
    };
  }

  Future<Result<AuthState, LoginFlowError>> _onStepRequired(
    AuthorizationAttempt sent,
    ChallengeStepRequired step,
  ) async {
    final attempt = sent.copyWith(authSession: step.authSession);
    _attempt = attempt;
    if (step.next == ChallengeStep.upstreamToken) {
      return _answerUpstream(step);
    }
    if (step.next == ChallengeStep.webauthnAssertion) {
      return _answerWebauthnAssertion(step);
    }
    return Ok(
      _emit(
        ChallengeRequired(
          prompt: ChallengePrompt.fromResponse(
            step,
            loginHint: attempt.loginHint,
          ),
          purpose: attempt.purpose,
        ),
      ),
    );
  }

  Future<Result<AuthState, LoginFlowError>> _answerUpstream(
    ChallengeStepRequired step,
  ) async {
    final prompt = step.upstream;
    if (prompt == null) {
      return _abandon(
        const ServerResponseInvalid(
          statusCode: 403,
          description: 'upstream_token step without "upstream"',
        ),
      );
    }
    final source = _nativeSourceFor(prompt.provider);
    if (source == null) {
      return _abandon(
        UpstreamFailed(
          provider: prompt.provider,
          reason: UpstreamFailureReason.notConfigured,
        ),
      );
    }
    final obtained = await source.obtainToken(prompt);
    if (obtained case Err(:final error)) {
      return _abandon(error);
    }
    final token = obtained.data;
    return _continueAttempt(
      UpstreamTokenInput(
        provider: prompt.provider,
        token: token.token,
        tokenType: token.tokenType,
        givenName: token.givenName,
        familyName: token.familyName,
      ),
    );
  }

  Future<Result<AuthState, LoginFlowError>> _answerWebauthnAssertion(
    ChallengeStepRequired step,
  ) async {
    final authenticator = _passkeyAuthenticator;
    final options = step.options;
    if (authenticator == null) {
      return _abandon(
        const PasskeyFailed(reason: PasskeyFailureReason.notConfigured),
      );
    }
    if (options == null) {
      return _abandon(
        const ServerResponseInvalid(
          statusCode: 403,
          description: 'webauthn_assertion step without "options"',
        ),
      );
    }
    final assertion = await authenticator.getAssertion(options: options);
    if (assertion case Err(:final error)) {
      return _abandon(error);
    }
    return _continueAttempt(WebauthnAssertionInput(assertion: assertion.data));
  }

  Future<Result<AuthState, LoginFlowError>> _onRedirectToWeb(
    DiscoveryDocument discovery,
    AuthorizationAttempt sent,
    ChallengeRedirectToWeb redirect,
  ) async {
    final attempt = sent.copyWith(authSession: redirect.authSession);
    _attempt = attempt;
    return _openAuthorization(
      discovery,
      attempt,
      requestUri: redirect.requestUri,
    );
  }

  Future<Result<AuthState, LoginFlowError>> _onSessionInvalid(
    AuthorizationAttempt sent,
  ) async {
    _attempt = null;
    if (sent.purpose == ChallengePurpose.signIn) {
      return Ok(_emit(const SignedOut(reason: SignOutReason.challengeExpired)));
    }
    return Ok(_emit(_restingState()));
  }

  Future<Result<AuthState, LoginFlowError>> _openAuthorization(
    DiscoveryDocument discovery,
    AuthorizationAttempt attempt, {
    required String? requestUri,
  }) async {
    final redirectUri = config.redirectUri;
    if (redirectUri == null || _userAgent == null) {
      return _abandon(
        const BrowserFailed(
          reason: BrowserFailureReason.unavailable,
          description: 'No redirect URI or system browser for this client.',
        ),
      );
    }
    final request = AuthorizationRequest(
      clientId: config.clientId,
      redirectUri: redirectUri,
      scope: _scopeFor(discovery),
      state: attempt.state,
      nonce: attempt.nonce,
      codeChallenge: attempt.pkce.codeChallenge,
      prompt: attempt.prompt,
      loginHint: attempt.loginHint,
      requestUri: requestUri,
    );
    return _runBrowser(
      request.toUri(discovery.authorizationEndpoint),
      PendingAuthorization(
        purpose: attempt.purpose == ChallengePurpose.stepUp
            ? PendingPurpose.stepUp
            : PendingPurpose.signIn,
        state: attempt.state,
        redirectUri: redirectUri,
        createdAt: _clock.now(),
        codeVerifier: attempt.pkce.codeVerifier,
        nonce: attempt.nonce,
      ),
    );
  }

  Future<Result<AuthState, LoginFlowError>> _runBrowser(
    Uri url,
    PendingAuthorization pending,
  ) async {
    final userAgent = _userAgent;
    if (userAgent == null) {
      return _abandon(
        const BrowserFailed(reason: BrowserFailureReason.unavailable),
      );
    }
    final saved = await _pendingStore.write(pending);
    if (saved case Err(:final error)) {
      return _abandon(error);
    }
    _emit(const AwaitingBrowser());
    final outcome = await userAgent.open(
      url,
      callbackUri: pending.redirectUri,
      expectedState: pending.state,
    );
    if (outcome case Err(:final error)) {
      await _clearPending();
      return _abandon(error);
    }
    return switch (outcome.data) {
      UserAgentCallback(:final uri) => _onBrowserReturned(uri, pending),
      UserAgentNavigatedAway() => Ok(_state),
    };
  }

  /// The user agent returned a navigation. An expired request ends the
  /// attempt. A navigation that does not match is refused but the pending
  /// request is kept: on Android the Custom Tab may still deliver the real
  /// callback, and a forged one must not abort a legitimate sign-in
  /// (`doc/decisions.md` D17).
  Future<Result<AuthState, LoginFlowError>> _onBrowserReturned(
    Uri uri,
    PendingAuthorization pending,
  ) async {
    if (_clock.now().difference(pending.createdAt) > pendingLifetime) {
      await _clearPending();
      return _abandon(
        const AuthorizationResponseRejected(
          problem: AuthorizationResponseProblem.requestExpired,
        ),
      );
    }
    if (!_matches(uri, pending)) {
      Log.w('Ignoring a browser callback that does not match the request.');
      _attempt = null;
      _emit(_restingState());
      return Err(
        const AuthorizationResponseRejected(
          problem: AuthorizationResponseProblem.stateMismatch,
        ),
      );
    }
    return _completeMatched(uri, pending);
  }

  Future<Result<AuthState, LoginFlowError>> _redeemCode(
    DiscoveryDocument discovery, {
    required String code,
    required String codeVerifier,
    required String? nonce,
    required Uri? redirectUri,
    required bool isBrowserUsed,
    required FlowOrigin origin,
  }) async {
    final ssoEntry = await _readSsoEntry();
    final response = await _tokens.request(
      discovery.tokenEndpoint,
      AuthorizationCodeGrant(
        code: code,
        codeVerifier: codeVerifier,
        redirectUri: redirectUri,
        deviceSecret: ssoEntry?.deviceSecret,
      ),
    );
    if (!_isCurrentOrigin(origin)) {
      if (response case Ok(data: final tokens)) {
        await _discardLate(tokens);
      }
      return Err(const NoChallengeInProgress());
    }
    if (response case Err(:final error)) {
      return _abandon(error);
    }
    return _acceptTokens(
      discovery,
      response.data,
      expectations: IdTokenExpectations.forClient(
        clientId: config.clientId,
        nonce: nonce,
        subject: origin.stepUpSubject,
      ),
      isBrowserUsed: isBrowserUsed,
      isSsoBound: false,
      origin: origin,
      nonce: nonce,
    );
  }

  bool _isCurrentOrigin(FlowOrigin origin) =>
      origin.generation == _generation && identical(origin.attempt, _attempt);

  FlowOrigin _captureOrigin({required bool isStepUp}) => FlowOrigin(
    generation: _generation,
    attempt: _attempt,
    stepUpSubject: isStepUp ? _session?.identity.subject : null,
  );

  Future<Result<AuthState, LoginFlowError>> _acceptTokens(
    DiscoveryDocument discovery,
    TokenResponse response, {
    required IdTokenExpectations expectations,
    required bool isBrowserUsed,
    required bool isSsoBound,
    required FlowOrigin origin,
    String? nonce,
  }) async {
    final idToken = response.idToken;
    final refreshToken = response.refreshToken;
    if (idToken == null || refreshToken == null) {
      return _abandon(
        const ServerResponseInvalid(
          statusCode: 200,
          description: 'The token response lacks id_token or refresh_token.',
        ),
      );
    }
    final claims = await _idTokens.validate(
      idToken,
      discovery: discovery,
      expectations: expectations,
    );
    final boundKey = await _boundKeyOf(response);
    if (!_isCurrentOrigin(origin)) {
      await _discardLate(response);
      return Err(const NoChallengeInProgress());
    }
    if (claims case Err(:final error)) {
      return _abandon(error);
    }
    final deviceSecret = response.deviceSecret;
    final store = _ssoStore;
    final previous = _session?.stored;
    final stored = StoredSession(
      refreshToken: refreshToken,
      idToken: idToken,
      scope: response.scope ?? _scopeFor(discovery),
      authSession: response.authSession ?? _attempt?.authSession,
      nonce: nonce,
      isBrowserSessionUsed:
          isBrowserUsed || (previous?.isBrowserSessionUsed ?? false),
      isSsoBound: isSsoBound || (deviceSecret != null && store != null),
      dpopJkt: boundKey,
    );
    _generation++;
    _refreshing = null;
    // The new session's own origin: a sign-out or cancel during the local
    // writes below changes it (`doc/decisions.md` D9).
    final persisting = _captureOrigin(isStepUp: false);
    final saved = await _sessionStore.write(stored);
    if (!_isCurrentOrigin(persisting)) {
      return _rollBackLate(response, stored: stored);
    }
    if (saved case Err(:final error)) {
      return _abandon(error);
    }
    if (deviceSecret != null) {
      await _writeSsoEntry(deviceSecret: deviceSecret, idToken: idToken);
      if (!_isCurrentOrigin(persisting)) {
        return _rollBackLate(
          response,
          stored: stored,
          deviceSecret: deviceSecret,
        );
      }
    }
    final session = ActiveSession(
      stored: stored,
      identity: UserIdentity.fromClaims(claims.data),
      accessToken: response.accessToken,
      accessTokenExpiresAt: _clock.now().add(response.expiresIn),
    );
    _session = session;
    _attempt = null;
    return Ok(_emit(SignedIn(session: session.toPublic())));
  }

  /// Undoes the writes of a session that was ended while it was being
  /// persisted, without touching anything a newer session wrote since, and
  /// revokes its refresh token. Emits nothing.
  Future<Result<AuthState, LoginFlowError>> _rollBackLate(
    TokenResponse response, {
    required StoredSession stored,
    String? deviceSecret,
  }) async {
    final current = await _sessionStore.read();
    if (current case Ok(data: final written) when written == stored) {
      await _sessionStore.clear();
    }
    final entry = await _readSsoEntry();
    if (deviceSecret != null && entry?.deviceSecret == deviceSecret) {
      await _deleteSsoEntry();
    }
    await _discardLate(response);
    return Err(const NoChallengeInProgress());
  }

  Future<Result<String, LoginFlowError>> _startRefresh() {
    late final Future<Result<String, LoginFlowError>> refresh;
    refresh = _refresh(_generation).whenComplete(() {
      if (identical(_refreshing, refresh)) {
        _refreshing = null;
      }
    });
    _refreshing = refresh;
    return refresh;
  }

  Future<Result<String, LoginFlowError>> _refresh(int generation) async {
    final current = _session;
    if (current == null) {
      return Err(const NotSignedIn());
    }
    final session = await _withLatestRefreshToken(current);
    if (!_isCurrent(generation)) {
      return Err(const NotSignedIn());
    }
    final discoveryResult = await _discovery.load();
    if (discoveryResult case Err(:final error)) {
      return Err(error);
    }
    final discovery = discoveryResult.data;
    final ssoEntry = session.stored.isSsoBound ? await _readSsoEntry() : null;
    final response = await _tokens.request(
      discovery.tokenEndpoint,
      RefreshTokenGrant(
        refreshToken: session.stored.refreshToken,
        deviceSecret: ssoEntry?.deviceSecret,
      ),
    );
    return response.when(
      ok: (tokens) => _acceptRefresh(discovery, session, tokens, generation),
      err: (error) => _refreshFailed(error, generation),
    );
  }

  bool _isCurrent(int generation) => generation == _generation;

  /// [session] with the refresh token currently in the store when another
  /// instance over the same store (a second browser tab of the app) rotated
  /// it since this one read it: presenting the older, already-used token
  /// would look like reuse and revoke the whole family (RFC 9700 §4.14.2).
  Future<ActiveSession> _withLatestRefreshToken(ActiveSession session) async {
    final storedResult = await _sessionStore.read();
    final latest = storedResult.when(
      ok: (stored) => stored,
      err: (error) {
        Log.w('Re-reading the stored session failed: ${error.message}');
        return null;
      },
    );
    final isRotatedElsewhere =
        latest != null &&
        latest.refreshToken != session.stored.refreshToken &&
        _readStoredClaims(latest.idToken)?.subject == session.identity.subject;
    return isRotatedElsewhere ? session.copyWith(stored: latest) : session;
  }

  /// Tokens that arrive after the session or attempt they belonged to
  /// ended: never stored, and their refresh token is revoked.
  Future<void> _discardLate(TokenResponse response) async {
    Log.w('Discarding tokens that arrived after their session or attempt.');
    await _revokeIfPresent(response.refreshToken);
  }

  Future<Result<String, LoginFlowError>> _discardLateRefresh(
    TokenResponse response,
  ) async {
    await _discardLate(response);
    return Err(const NotSignedIn());
  }

  Future<Result<String, LoginFlowError>> _acceptRefresh(
    DiscoveryDocument discovery,
    ActiveSession session,
    TokenResponse response,
    int generation,
  ) async {
    if (!_isCurrent(generation)) {
      return _discardLateRefresh(response);
    }
    final idToken = response.idToken;
    var identity = session.identity;
    if (idToken != null) {
      final claims = await _idTokens.validate(
        idToken,
        discovery: discovery,
        expectations: IdTokenExpectations.forClient(
          clientId: config.clientId,
          subject: session.identity.subject,
        ),
      );
      if (!_isCurrent(generation)) {
        return _discardLateRefresh(response);
      }
      if (claims case Err(:final error)) {
        Log.e('Refreshed ID token rejected; ending the local session.');
        await _endLocalSession(SignOutReason.sessionRevoked);
        await _revokeIfPresent(response.refreshToken);
        return Err(error);
      }
      identity = UserIdentity.fromClaims(claims.data);
    }
    final stored = session.stored.copyWith(
      refreshToken: response.refreshToken,
      idToken: idToken,
      scope: response.scope,
      authSession: response.authSession,
    );
    final saved = await _sessionStore.write(stored);
    if (saved case Err(:final error)) {
      Log.e('The rotated refresh token could not be persisted; signing out.');
      await _endLocalSession(SignOutReason.sessionRevoked);
      await _revokeIfPresent(response.refreshToken);
      return Err(error);
    }
    if (!_isCurrent(generation)) {
      return _discardLateRefresh(response);
    }
    final updated = ActiveSession(
      stored: stored,
      identity: identity,
      accessToken: response.accessToken,
      accessTokenExpiresAt: _clock.now().add(response.expiresIn),
    );
    _session = updated;
    final deviceSecret = response.deviceSecret;
    if (deviceSecret != null && idToken != null) {
      await _writeSsoEntry(deviceSecret: deviceSecret, idToken: idToken);
    } else if (deviceSecret != null) {
      Log.w('Ignoring a device_secret issued without its ID token.');
    }
    if (identity != session.identity) {
      _emit(SignedIn(session: updated.toPublic()));
    }
    return Ok(response.accessToken);
  }

  Future<Result<String, LoginFlowError>> _refreshFailed(
    LoginFlowError error,
    int generation,
  ) async {
    if (!_isCurrent(generation)) {
      Log.w('Ignoring the failure of a refresh whose session already ended.');
      return Err(error);
    }
    if (error case OAuthProtocolError(code: 'invalid_grant')) {
      Log.w('Refresh token rejected; ending the local session.');
      await _endLocalSession(SignOutReason.sessionRevoked);
      return Err(const SessionRevoked());
    }
    if (error case InsufficientAuthorization(:final challenge)) {
      _attempt = AuthorizationAttempt.start(
        purpose: ChallengePurpose.reauthentication,
        randomSource: _randomSource,
        authSession: challenge.authSession,
      );
      _emit(
        ChallengeRequired(
          prompt: ChallengePrompt.fromResponse(challenge),
          purpose: ChallengePurpose.reauthentication,
        ),
      );
      return Err(const ReauthenticationRequired());
    }
    return Err(error);
  }

  Future<Result<AuthState, LoginFlowError>> _ssoExchangeFailed(
    LoginFlowError error,
    SsoEntry entry,
    FlowOrigin origin,
  ) async {
    if (!_isCurrentOrigin(origin)) {
      Log.w('Ignoring a Native SSO failure for a flow that already ended.');
      return Err(error);
    }
    if (error case OAuthProtocolError(code: 'invalid_grant')) {
      Log.w('The shared device session is no longer valid.');
      await _deleteSsoEntry();
      return Ok(_emit(const SignedOut(reason: SignOutReason.ssoUnavailable)));
    }
    if (error case OAuthProtocolError(code: 'interaction_required')) {
      return Ok(
        _emit(
          SignedOut(
            reason: SignOutReason.ssoUnavailable,
            loginHint: _readStoredClaims(entry.idToken)?.email,
          ),
        ),
      );
    }
    return Err(error);
  }

  Future<Result<AuthState, LoginFlowError>> _signOutApp() async {
    final session = _session;
    // Always end the local session, even with nothing signed in yet: it
    // invalidates a sign-in whose tokens are still being persisted.
    await _endLocalSession(SignOutReason.userRequested);
    if (session != null) {
      await _revoke(session.stored.refreshToken);
    }
    return Ok(_state);
  }

  Future<Result<AuthState, LoginFlowError>> _signOutServerSessions(
    Uri? Function(DiscoveryDocument discovery) endpointOf,
    String feature,
  ) async {
    if (_session == null) {
      return Err(const NotSignedIn());
    }
    final discoveryResult = await _discovery.load();
    if (discoveryResult case Err(:final error)) {
      return Err(error);
    }
    final endpoint = endpointOf(discoveryResult.data);
    if (endpoint == null) {
      return Err(UnsupportedByServer(feature: feature));
    }
    final token = await accessToken();
    if (token case Err(:final error)) {
      if (error is SessionRevoked) {
        await _deleteSsoEntry();
        return Ok(_state);
      }
      return Err(error);
    }
    final ended = await _sessionLogout.endSessions(endpoint, token.data);
    if (ended case Err(:final error)) {
      return Err(error);
    }
    await _deleteSsoEntry();
    await _endLocalSession(SignOutReason.userRequested);
    return Ok(_state);
  }

  Future<Result<AuthState, LoginFlowError>> _signOutBrowser() async {
    final session = _session;
    if (session == null) {
      return Err(const NotSignedIn());
    }
    final discoveryResult = await _discovery.load();
    if (discoveryResult case Err(:final error)) {
      return Err(error);
    }
    final endpoint = discoveryResult.data.endSessionEndpoint;
    final postLogoutRedirectUri = config.postLogoutRedirectUri;
    if (endpoint == null) {
      return Err(const UnsupportedByServer(feature: 'end_session_endpoint'));
    }
    if (postLogoutRedirectUri == null || _userAgent == null) {
      return Err(
        const BrowserFailed(
          reason: BrowserFailureReason.unavailable,
          description: 'No post_logout_redirect_uri or system browser.',
        ),
      );
    }
    final state = _randomSource.nextOpaqueToken();
    final request = EndSessionRequest(
      clientId: config.clientId,
      idTokenHint: session.stored.idToken,
      postLogoutRedirectUri: postLogoutRedirectUri,
      state: state,
    );
    await _endLocalSession(SignOutReason.userRequested);
    await _revoke(session.stored.refreshToken);
    return _runBrowser(
      request.toUri(endpoint),
      PendingAuthorization(
        purpose: PendingPurpose.signOut,
        state: state,
        redirectUri: postLogoutRedirectUri,
        createdAt: _clock.now(),
      ),
    );
  }

  /// RFC 7009 revocation. A failure is logged and does not block the local
  /// sign-out the user asked for; the refresh token still expires on its own.
  Future<void> _revoke(String refreshToken) async {
    final discoveryResult = await _discovery.load();
    final endpoint = discoveryResult.when(
      ok: (discovery) => discovery.revocationEndpoint,
      err: (_) => null,
    );
    if (endpoint == null) {
      Log.w('No revocation endpoint available; skipping revocation.');
      return;
    }
    final revoked = await _revocation.revokeRefreshToken(
      endpoint,
      refreshToken,
    );
    if (revoked case Err(:final error)) {
      Log.w('Refresh token revocation failed: ${error.message}');
    }
  }

  Future<void> _revokeIfPresent(String? refreshToken) async {
    if (refreshToken != null) {
      await _revoke(refreshToken);
    }
  }

  /// Ends the local session: in-flight refreshes are invalidated first so a
  /// late response can neither restore nor overwrite anything.
  Future<void> _endLocalSession(SignOutReason reason) async {
    _generation++;
    _refreshing = null;
    final cleared = await _sessionStore.clear();
    if (cleared case Err(:final error)) {
      Log.e('Clearing the stored session failed: ${error.message}');
    }
    _session = null;
    _attempt = null;
    _emit(SignedOut(reason: reason));
  }

  Future<SsoCandidate?> _ssoCandidate() async {
    final entry = await _readSsoEntry();
    if (entry == null) {
      return null;
    }
    final discoveryResult = await _discovery.load();
    if (discoveryResult case Err(:final error)) {
      Log.w('Native SSO check skipped: ${error.message}');
      return null;
    }
    final claims = await _idTokens.validate(
      entry.idToken,
      discovery: discoveryResult.data,
      expectations: const IdTokenExpectations.sharedSsoToken(),
    );
    if (claims case Err(:final error)) {
      if (error case IdTokenRejected(reason: != IdTokenFailure.unknownKey)) {
        Log.w('The shared SSO entry is not trustworthy; deleting it.');
        await _deleteSsoEntry();
      }
      return null;
    }
    final verified = claims.data;
    return SsoCandidate(
      subject: verified.subject,
      name: verified.name,
      email: verified.email,
      companyId: verified.companyId,
    );
  }

  Future<SsoEntry?> _readSsoEntry() async {
    final store = _ssoStore;
    if (store == null) {
      return null;
    }
    final entry = await store.read(config.issuer.toString());
    return entry.when(
      ok: (entry) => entry,
      err: (error) {
        Log.w('Reading the shared SSO entry failed: ${error.message}');
        return null;
      },
    );
  }

  Future<void> _writeSsoEntry({
    required String deviceSecret,
    required String idToken,
  }) async {
    final store = _ssoStore;
    if (store == null) {
      return;
    }
    final written = await store.write(
      SsoEntry(
        issuer: config.issuer.toString(),
        deviceSecret: deviceSecret,
        idToken: idToken,
        updatedAt: _clock.now(),
      ),
    );
    if (written case Err(:final error)) {
      Log.w('Writing the shared SSO entry failed: ${error.message}');
    }
  }

  Future<void> _deleteSsoEntry() async {
    final deleted = await _ssoStore?.delete(config.issuer.toString());
    if (deleted case Err(:final error)) {
      Log.w('Deleting the shared SSO entry failed: ${error.message}');
    }
  }

  Future<void> _clearPending() async {
    final cleared = await _pendingStore.clear();
    if (cleared case Err(:final error)) {
      Log.w('Clearing the pending authorization failed: ${error.message}');
    }
  }

  /// Ends the attempt in progress, returns to the resting state and reports
  /// [error].
  Future<Result<AuthState, LoginFlowError>> _abandon(
    LoginFlowError error,
  ) async {
    _attempt = null;
    _emit(_restingState());
    return Err(error);
  }

  AuthState _restingState() {
    final session = _session;
    return session == null
        ? const SignedOut()
        : SignedIn(session: session.toPublic());
  }

  String _scopeFor(DiscoveryDocument discovery) => <String>{
    'openid',
    'offline_access',
    if (_ssoStore != null && discovery.isNativeSsoSupported) 'device_sso',
    ...config.scopes,
  }.join(' ');

  AuthState _emit(AuthState state) {
    _state = state;
    if (!_states.isClosed) {
      _states.add(state);
    }
    return state;
  }
}

/// Wraps a [GoogleIdTokenSource] as an [UpstreamTokenSource] so
/// [LoginFlowAuth._answerUpstream] handles Google the same way as every
/// other provider, with no dedicated branch.
class _GoogleUpstreamTokenSourceAdapter implements UpstreamTokenSource {
  const _GoogleUpstreamTokenSourceAdapter(this._source);

  final GoogleIdTokenSource _source;

  @override
  bool get isAvailable => true;

  @override
  Future<Result<ObtainedUpstreamToken, LoginFlowError>> obtainToken(
    UpstreamPrompt prompt,
  ) async {
    final token = await _source.obtainIdToken(prompt);
    return token.when(
      ok: (idToken) => Ok(
        ObtainedUpstreamToken(
          token: idToken,
          tokenType: UpstreamTokenType.idToken,
        ),
      ),
      err: Err.new,
    );
  }
}
