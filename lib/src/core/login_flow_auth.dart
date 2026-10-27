import 'dart:async';

import 'package:http/http.dart' as http;
import 'package:logger_rs/logger_rs.dart';
import 'package:loginflow_auth/src/core/access_code/access_code_format.dart';
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
import 'package:loginflow_auth/src/core/flow/issued_access_token.dart';
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
import 'package:loginflow_auth/src/core/protocol/email_change/email_change_client.dart';
import 'package:loginflow_auth/src/core/protocol/email_change/email_change_confirmed.dart';
import 'package:loginflow_auth/src/core/protocol/email_change/email_change_started.dart';
import 'package:loginflow_auth/src/core/protocol/login_options/client_login_options.dart';
import 'package:loginflow_auth/src/core/protocol/login_options/login_options_client.dart';
import 'package:loginflow_auth/src/core/protocol/logout/revocation_client.dart';
import 'package:loginflow_auth/src/core/protocol/logout/session_logout_client.dart';
import 'package:loginflow_auth/src/core/protocol/members/app_members_client.dart';
import 'package:loginflow_auth/src/core/protocol/members/grantable_roles.dart';
import 'package:loginflow_auth/src/core/protocol/members/member_assignment.dart';
import 'package:loginflow_auth/src/core/protocol/members/member_invitation.dart';
import 'package:loginflow_auth/src/core/protocol/members/members_page.dart';
import 'package:loginflow_auth/src/core/protocol/organizations/organization_list.dart';
import 'package:loginflow_auth/src/core/protocol/organizations/organizations_client.dart';
import 'package:loginflow_auth/src/core/protocol/passkeys/passkey_account_client.dart';
import 'package:loginflow_auth/src/core/protocol/passkeys/passkey_credential.dart';
import 'package:loginflow_auth/src/core/protocol/password_change/password_change_client.dart';
import 'package:loginflow_auth/src/core/protocol/step_up/step_up_requirement.dart';
import 'package:loginflow_auth/src/core/protocol/token/token_client.dart';
import 'package:loginflow_auth/src/core/protocol/token/token_grant.dart';
import 'package:loginflow_auth/src/core/protocol/token/token_response.dart';
import 'package:loginflow_auth/src/core/protocol/totp/totp_account_client.dart';
import 'package:loginflow_auth/src/core/protocol/totp/totp_enrollment.dart';
import 'package:loginflow_auth/src/core/protocol/totp/totp_status.dart';
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
///
/// Every method that opens a sign-in takes an optional `organization`: the
/// `Organization.id` the session starts in (`doc/server-contract.md` §17).
/// Without it the server activates the user's only organization, or none
/// when they have several — then [listOrganizations] and
/// [switchOrganization]. The server refuses an organization of another
/// application.
class LoginFlowAuth {
  /// Creates the client. Apps use `LoginFlowPlatform.createAuth`, which wires
  /// the platform stores, browser and passkeys; this constructor is for tests
  /// and custom platforms. [dpopKeyStore] is only used with
  /// [LoginFlowConfig.enableDpop].
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
    _totpAccount = TotpAccountClient(
      transport: transport,
      issuer: config.issuer,
    );
    _passwordChange = PasswordChangeClient(
      transport: transport,
      issuer: config.issuer,
    );
    _organizations = OrganizationsClient(transport: transport);
    _appMembers = AppMembersClient(transport: transport, issuer: config.issuer);
    _emailChange = EmailChangeClient(
      transport: transport,
      issuer: config.issuer,
    );
  }

  /// How this app identifies itself to LoginFlow.
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
  late final TotpAccountClient _totpAccount;
  late final PasswordChangeClient _passwordChange;
  late final OrganizationsClient _organizations;
  late final AppMembersClient _appMembers;
  late final EmailChangeClient _emailChange;

  final StreamController<AuthState> _states =
      StreamController<AuthState>.broadcast();

  AuthState _state = const AuthInitializing();
  AuthorizationAttempt? _attempt;
  ActiveSession? _session;

  /// The refreshes in flight, keyed by the API they renew the token of
  /// (`null`: the session's own token). Concurrent callers for one share it.
  final Map<String?, Future<Result<String, LoginFlowError>>> _refreshing =
      <String?, Future<Result<String, LoginFlowError>>>{};

  /// Every refresh rotates the refresh token, so refreshes run one after
  /// another: two in flight would present the same token and the server
  /// would revoke the family as reused (RFC 9700 §4.14.2).
  Future<void> _refreshQueue = Future<void>.value();

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
  Future<Result<AuthState, LoginFlowError>> beginSignIn({
    String? loginHint,
    String? organization,
  }) => _startAttempt(
    purpose: ChallengePurpose.signIn,
    loginHint: loginHint,
    organization: organization,
    input: loginHint == null ? null : LoginHintInput(loginHint: loginHint),
  );

  /// Identifier and password in one request.
  Future<Result<AuthState, LoginFlowError>> signInWithPassword({
    required String loginHint,
    required String password,
    String? organization,
  }) => _startAttempt(
    purpose: ChallengePurpose.signIn,
    loginHint: loginHint,
    organization: organization,
    input: PasswordSignInInput(loginHint: loginHint, password: password),
  );

  /// Asks the server to email a one-time code to [loginHint].
  Future<Result<AuthState, LoginFlowError>> requestEmailOtp({
    required String loginHint,
    String? organization,
  }) => _startAttempt(
    purpose: ChallengePurpose.signIn,
    loginHint: loginHint,
    organization: organization,
    input: IdentifierInput(
      loginHint: loginHint,
      method: ChallengeStep.emailOtp,
    ),
  );

  /// Answers `next: email_otp` with the emailed [code].
  Future<Result<AuthState, LoginFlowError>> submitEmailOtp(String code) =>
      _continueAttempt(EmailOtpInput(code: code));

  /// Asks the server for a new email code on the current step.
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

  /// Answers `next: password` (or a password step chosen with [selectMethod]).
  Future<Result<AuthState, LoginFlowError>> submitPassword(String password) =>
      _continueAttempt(PasswordInput(password: password));

  /// Answers `next: totp` with the authenticator app's 6-digit [code].
  Future<Result<AuthState, LoginFlowError>> submitTotp(String code) =>
      _continueAttempt(TotpInput(code: code));

  /// Answers the second-factor step with a single-use TOTP recovery [code].
  Future<Result<AuthState, LoginFlowError>> submitRecoveryCode(String code) =>
      _continueAttempt(RecoveryCodeInput(code: code));

  /// Chooses one of the alternatives of the current prompt
  /// ([ChallengePrompt.alternatives]).
  ///
  /// A step the user answers with a typed value ([ChallengeStep.password],
  /// [ChallengeStep.totp], [ChallengeStep.recoveryCode],
  /// [ChallengeStep.temporaryAccessPass]) has no `method` on the server,
  /// which takes that value on any step: choosing one only changes the
  /// prompt, with no request; then call [submitPassword], [submitTotp],
  /// [submitRecoveryCode] or [submitTemporaryAccessPass]. The others act
  /// on the server and are sent as `method`: [ChallengeStep.emailOtp]
  /// emails a code, [ChallengeStep.magicLink] a sign-in link, and
  /// [ChallengeStep.webauthnIdentify] runs the passkey ceremony.
  Future<Result<AuthState, LoginFlowError>> selectMethod(
    ChallengeStep method,
  ) => switch (method) {
    ChallengeStep.password ||
    ChallengeStep.totp ||
    ChallengeStep.recoveryCode ||
    ChallengeStep.temporaryAccessPass => _promptFor(method),
    _ => _continueAttempt(MethodSelectionInput(method: method)),
  };

  /// Re-emits the current challenge asking for [step], on the same
  /// `auth_session`, without a request.
  Future<Result<AuthState, LoginFlowError>> _promptFor(
    ChallengeStep step,
  ) async {
    final attempt = _attempt;
    final current = _state;
    if (attempt == null || current is! ChallengeRequired) {
      return Err(const NoChallengeInProgress());
    }
    return Ok(
      _emit(
        ChallengeRequired(
          prompt: ChallengePrompt(
            step: step,
            alternatives: current.prompt.alternatives,
            loginHint: attempt.loginHint,
          ),
          purpose: current.purpose,
        ),
      ),
    );
  }

  /// Passkey (WebAuthn L3) sign-in: targeted when [loginHint] is given,
  /// discoverable/conditional otherwise — with no arguments it also signs in
  /// an access-code subject that enrolled a passkey ([enrollPasskey]),
  /// into the same subject session a code gives. The platform ceremony
  /// ([PasskeyAuthenticator.getAssertion]) runs automatically once the
  /// server answers with its options — same shape as [signInWithGoogle],
  /// never surfaced as a [ChallengeRequired] state.
  Future<Result<AuthState, LoginFlowError>> signInWithPasskey({
    String? loginHint,
    String? organization,
  }) => _startAttempt(
    purpose: ChallengePurpose.signIn,
    loginHint: loginHint,
    organization: organization,
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
    String? organization,
  }) => _startAttempt(
    purpose: ChallengePurpose.signIn,
    loginHint: loginHint,
    organization: organization,
    input: TemporaryAccessPassSignInInput(loginHint: loginHint, code: code),
  );

  /// Continues an attempt whose identity is already bound to the
  /// `auth_session` (step-up/reauthentication) with just the code.
  Future<Result<AuthState, LoginFlowError>> submitTemporaryAccessPass(
    String code,
  ) => _continueAttempt(TemporaryAccessPassInput(code: code));

  /// Redeems a single-use access code a tenant backend issued for one of
  /// its own subjects (a driver, a student, a kiosk) — `method=access_code`
  /// on the challenge endpoint, answered in one leg
  /// (`doc/server-contract.md` §16). [code] may be typed in any case, with
  /// spaces or the display dash; it is [AccessCodeFormat.normalize]d first.
  ///
  /// The session is bound to this device's DPoP key, so DPoP is required:
  /// without [LoginFlowConfig.enableDpop] and a `DpopKeyStore` this fails
  /// with [ConfigurationInvalid] before any request. Other failures, from
  /// the server's RFC 6749 error bodies:
  /// - [InvalidAccessCode]: malformed (refused locally, no request), or
  ///   `400 {"error":"invalid_grant"}` for an unknown, expired, used or
  ///   revoked code — the server never tells them apart.
  /// - [AccessCodeThrottled]: `429 {"error":"slow_down"}`, with
  ///   [AccessCodeThrottled.retryAfter] from the `Retry-After` header
  ///   (seconds).
  /// - [AccessCodesUnavailable]: `400 {"error":"access_codes_disabled"}`, or
  ///   a server that answers the `access_code` method with a step instead
  ///   of a code.
  /// - [UnsupportedByServer] (`feature: 'authorization_challenge_endpoint'`):
  ///   the discovery document has no `authorization_challenge_endpoint`, so
  ///   there is nowhere to redeem the code.
  /// - Any other refusal comes back as [OAuthProtocolError] with the
  ///   server's `error` code: `unauthorized_client` (this client's login
  ///   methods lack `access_code`, or it may not redeem codes at all),
  ///   `invalid_dpop_proof`, `invalid_scope`, `invalid_request`,
  ///   `temporarily_unavailable`.
  ///
  /// The signed-in identity carries `externalSubject`, `subjectKind` and
  /// `subjectProfile` (the `ext_sub`, `subject_kind` and `ext_profile`
  /// claims).
  ///
  /// Unlike the other sign-in methods this takes no `organization`: the
  /// server issues an access code's authorization code without one, so the
  /// session starts in the subject's only organization, or in none — then
  /// [switchOrganization].
  Future<Result<AuthState, LoginFlowError>> signInWithAccessCode(
    String code,
  ) async {
    if (_dpop == null) {
      return Err(
        const ConfigurationInvalid(
          description:
              'Access-code sign-in needs LoginFlowConfig.enableDpop and a '
              'DpopKeyStore: the session is bound to the device key.',
        ),
      );
    }
    final normalized = AccessCodeFormat.normalize(code);
    if (!AccessCodeFormat.isComplete(normalized)) {
      return Err(const InvalidAccessCode());
    }
    return _startAttempt(
      purpose: ChallengePurpose.signIn,
      input: AccessCodeInput(code: normalized),
    );
  }

  /// Google natively when a [GoogleIdTokenSource] is configured, otherwise in
  /// the system browser.
  Future<Result<AuthState, LoginFlowError>> signInWithGoogle({
    String? organization,
  }) => _startAttempt(
    purpose: ChallengePurpose.signIn,
    organization: organization,
    input: UpstreamStartInput(
      provider: UpstreamProvider.google,
      flow: _googleIdTokenSource == null
          ? UpstreamFlow.browser
          : UpstreamFlow.native,
    ),
  );

  /// Microsoft always runs in the system browser (`doc/decisions.md` D4).
  Future<Result<AuthState, LoginFlowError>> signInWithMicrosoft({
    String? organization,
  }) => _startAttempt(
    purpose: ChallengePurpose.signIn,
    organization: organization,
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
  Future<Result<AuthState, LoginFlowError>> signInWithApple({
    String? organization,
  }) => _startAttempt(
    purpose: ChallengePurpose.signIn,
    organization: organization,
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
  Future<Result<AuthState, LoginFlowError>> signInWithFacebook({
    String? organization,
  }) => _startAttempt(
    purpose: ChallengePurpose.signIn,
    organization: organization,
    input: UpstreamStartInput(
      provider: UpstreamProvider.facebook,
      flow: _nativeSourceFor(UpstreamProvider.facebook) == null
          ? UpstreamFlow.browser
          : UpstreamFlow.native,
    ),
  );

  /// Self sign-up (`prompt=create`); the server continues in the browser.
  Future<Result<AuthState, LoginFlowError>> signUp({String? organization}) =>
      _startAttempt(
        purpose: ChallengePurpose.signIn,
        prompt: AuthorizationPrompt.create.wireName,
        organization: organization,
      );

  /// Password reset on the hosted pages (first-party-apps App. A.2).
  Future<Result<AuthState, LoginFlowError>> resetPassword({
    String? loginHint,
    String? organization,
  }) => _startAttempt(
    purpose: ChallengePurpose.signIn,
    loginHint: loginHint,
    organization: organization,
    input: PasswordResetInput(loginHint: loginHint),
  );

  /// Authorization code + PKCE through the system browser. On the web this
  /// is a top-level redirect: try [AuthorizationPrompt.none] first and fall
  /// back to an interactive request on `SignOutReason.loginRequired`.
  Future<Result<AuthState, LoginFlowError>> signInWithBrowser({
    AuthorizationPrompt? prompt,
    String? loginHint,
    String? organization,
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
      organization: organization,
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
      // For display (`ChallengePrompt.loginHint`, "code sent to …"): the
      // challenge never sends it — the `auth_session` or `id_token_hint`
      // identifies the user. Only a browser hand-off without `request_uri`
      // would carry it as `login_hint`, naming that same signed-in user.
      loginHint: session.identity.email,
      authSession: authSession,
      acrValues: requirement.acrValues,
      maxAge: requirement.maxAge,
      idTokenHint: authSession == null ? session.stored.idToken : null,
      organization: session.stored.organizationId,
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

  /// A valid access token for [api] (an audience listed in
  /// [LoginFlowConfig.apis]), carrying only that API's permissions in the
  /// active organization. Cached per API and refreshed when needed, with
  /// `resource=<api>` (RFC 8707) on the same refresh family and DPoP key.
  /// Refreshes never overlap, so a rotated refresh token is never presented
  /// twice (RFC 9700 §4.14.2); concurrent callers for one API share one.
  ///
  /// Fails with [ConfigurationInvalid] for an API missing from
  /// [LoginFlowConfig.apis] (no request is sent), and with [InvalidTarget]
  /// when the server does not issue tokens for it to this client.
  Future<Result<String, LoginFlowError>> accessTokenFor(String api) async {
    if (!config.apis.contains(api)) {
      return Err(
        ConfigurationInvalid(
          description: 'the API "$api" is not in LoginFlowConfig.apis',
        ),
      );
    }
    final session = _session;
    if (session == null) {
      return Err(const NotSignedIn());
    }
    final fresh = session.freshApiToken(api, _clock.now());
    if (fresh != null) {
      return Ok(fresh);
    }
    return _refreshFor(api);
  }

  /// The `Authorization` and `DPoP` headers for ONE request of the app to
  /// [api] with its access token ([accessTokenFor]):
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
  Future<Result<ResourceAuthorization, LoginFlowError>> authorizedHeadersFor(
    String api, {
    required String method,
    required Uri uri,
  }) async {
    final tokenResult = await accessTokenFor(api);
    if (tokenResult case Err(:final error)) {
      return Err(error);
    }
    return _transport.authorize(
      httpMethod: method,
      uri: uri,
      accessToken: tokenResult.data,
    );
  }

  /// The organizations of this application where the signed-in user has
  /// an active assignment, and the one the session has active
  /// (`GET {organizations_endpoint}`, `doc/server-contract.md` §17).
  Future<Result<OrganizationList, LoginFlowError>> listOrganizations() async {
    final discoveryResult = await _discovery.load();
    if (discoveryResult case Err(:final error)) {
      return Err(error);
    }
    final endpoint = discoveryResult.data.organizationsEndpoint;
    if (endpoint == null) {
      return Err(const UnsupportedByServer(feature: 'organizations_endpoint'));
    }
    final tokenResult = await _sessionAccessToken();
    if (tokenResult case Err(:final error)) {
      return Err(error);
    }
    return _organizations.list(endpoint, bearerToken: tokenResult.data);
  }

  /// Makes [organizationId] the active organization of the whole session:
  /// a refresh with `organization` (`doc/server-contract.md` §17). Every
  /// cached API token belonged to the previous organization, so they are
  /// all dropped and [LoginFlowSession.accessClaims] empties; the next
  /// [accessTokenFor] gets a token for the new one. Fails with
  /// [OrganizationUnavailable] when the user has no active assignment there;
  /// the session then keeps its organization.
  Future<Result<void, LoginFlowError>> switchOrganization(
    String organizationId,
  ) async {
    if (_session == null) {
      return Err(const NotSignedIn());
    }
    final generation = _generation;
    // A token refresh asked for after this call must not join one that
    // started before it: that one is for the previous organization.
    _refreshing.clear();
    final switched = await _queued(
      () => _refresh(generation, organization: organizationId),
    );
    return switched.when(ok: (_) => Ok(null), err: Err.new);
  }

  /// The session's own access token (no `resource`), for LoginFlow's
  /// endpoints this library calls itself: passkeys, logout, organizations.
  Future<Result<String, LoginFlowError>> _sessionAccessToken() async {
    final session = _session;
    if (session == null) {
      return Err(const NotSignedIn());
    }
    final fresh = session.freshSessionToken(_clock.now());
    if (fresh != null) {
      return Ok(fresh);
    }
    return _refreshFor(null);
  }

  /// Enrolls a new passkey for the signed-in user: starts the ceremony,
  /// runs it on the platform ([PasskeyAuthenticator.createCredential]) and
  /// submits the result (`POST /v1/user/passkeys/enroll/{start,finish}`).
  /// The server requires a recently authenticated access token (RFC 9470):
  /// past that window this fails with [StepUpRequired] — call
  /// [stepUp] with its `requirement`, then call this again.
  ///
  /// Works on an access-code session too ([signInWithAccessCode]), `person`
  /// or `device`, within 300 s of redeeming the code; the next sign-in is
  /// then [signInWithPasskey] with no arguments. The server answers a
  /// passkey path it cannot serve (passkeys off for the company, `passkey`
  /// not among the client's login methods) with a coded `403`:
  /// [PasskeyAccountRefused], here and on [listPasskeys], [renamePasskey]
  /// and [deletePasskey].
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
    final tokenResult = await _sessionAccessToken();
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
    final tokenResult = await _sessionAccessToken();
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
    final tokenResult = await _sessionAccessToken();
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
    final tokenResult = await _sessionAccessToken();
    if (tokenResult case Err(:final error)) {
      return Err(error);
    }
    return _passkeyAccount.delete(bearerToken: tokenResult.data, id: id);
  }

  /// Whether the signed-in person has an authenticator app on
  /// (`GET /v1/user/totp/status`, `doc/server-contract.md` §20).
  ///
  /// The TOTP calls use the session's own token, like the passkey ones. An
  /// access-code session has no account to hold one: every TOTP call
  /// answers [TotpAccountRefused] there.
  Future<Result<TotpStatus, LoginFlowError>> totpStatus() =>
      _withSessionToken((token) => _totpAccount.status(bearerToken: token));

  /// Starts enrolling an authenticator app (`POST /v1/user/totp/setup`): a
  /// new secret and its `otpauth://` URI (show it as a QR code, and the
  /// secret for typing it by hand). Nothing changes for the account until
  /// [confirmTotpEnrollment]; a new start replaces the pending secret.
  /// [issuer] names the entry in the app (`Acme Console`); without it the
  /// server uses the application's name, then the company's.
  Future<Result<TotpEnrollment, LoginFlowError>> startTotpEnrollment({
    String? issuer,
  }) => _withSessionToken(
    (token) => _totpAccount.setup(bearerToken: token, issuer: issuer),
  );

  /// Turns the authenticator app on with a [code] it produced from the
  /// pending secret (`POST /v1/user/totp/verify-setup`). Fails with
  /// [InvalidTotpCode] for a wrong code or a locked account. The server
  /// issues no recovery codes here: call [regenerateRecoveryCodes] next.
  Future<Result<void, LoginFlowError>> confirmTotpEnrollment(String code) =>
      _withSessionToken(
        (token) => _totpAccount.verifySetup(bearerToken: token, code: code),
      );

  /// Turns the authenticator app off, confirmed with a current [code] from
  /// it (`POST /v1/user/totp/disable`). Fails with [InvalidTotpCode].
  Future<Result<void, LoginFlowError>> disableTotp(String code) =>
      _withSessionToken(
        (token) => _totpAccount.disable(bearerToken: token, code: code),
      );

  /// A new set of recovery codes, every earlier one void
  /// (`POST /v1/user/totp/recovery-codes`). Show them once; the library
  /// keeps none. Needs a recent sign-in: fails with [StepUpRequired] past
  /// 300 s — call [stepUp], then this again.
  Future<Result<List<String>, LoginFlowError>> regenerateRecoveryCodes() =>
      _withSessionToken(
        (token) => _totpAccount.regenerateRecoveryCodes(bearerToken: token),
      );

  /// Sets or changes the signed-in person's password to [newPassword], in
  /// the app (`POST /v1/user/change-password`): no current password, no
  /// browser. An account signed in with a provider or a code gets its first
  /// password. Matching a confirmation field is the app's job.
  ///
  /// Needs a recent sign-in, strong (`mfa`/`phr`) when the account has a
  /// second factor: fails with [StepUpRequired] otherwise — call [stepUp],
  /// then this again. Fails with [PasswordRejected] for a weak, breached or
  /// unchanged password, and [NotSignedIn] without a session. The server
  /// ends every other session of the person; this one continues.
  Future<Result<void, LoginFlowError>> changePassword(String newPassword) =>
      _withSessionToken(
        (token) => _passwordChange.change(
          bearerToken: token,
          newPassword: newPassword,
        ),
      );

  /// Runs [call] with the session's own token ([_sessionAccessToken]).
  Future<Result<T, LoginFlowError>> _withSessionToken<T>(
    Future<Result<T, LoginFlowError>> Function(String token) call,
  ) async {
    final tokenResult = await _sessionAccessToken();
    if (tokenResult case Err(:final error)) {
      return Err(error);
    }
    return call(tokenResult.data);
  }

  /// The roles the signed-in user may grant in [organizationId]
  /// (`GET /v1/app/members/grantable-roles`, `doc/server-contract.md` §18):
  /// exactly what [grantRole] there would allow. Empty
  /// [GrantableRoles.roles] means no grant power there: hide the "Team"
  /// screen. Fails with [DelegationDenied] (`organizationOutOfReach`,
  /// `organizationNotFound`).
  Future<Result<GrantableRoles, LoginFlowError>> listGrantableRoles({
    required String organizationId,
  }) => _withLoginFlowToken(
    (token) => _appMembers.grantableRoles(
      bearerToken: token,
      organizationId: organizationId,
    ),
  );

  /// The people holding a role in [organizationId], with those roles and
  /// whether the signed-in user may revoke each one (`GET /v1/app/members`).
  /// [query] matches part of the email; [limit] is 1 to 100.
  Future<Result<MembersPage, LoginFlowError>> listMembers({
    required String organizationId,
    String? query,
    int limit = 50,
    int offset = 0,
  }) => _withLoginFlowToken(
    (token) => _appMembers.list(
      bearerToken: token,
      organizationId: organizationId,
      query: query,
      limit: limit,
      offset: offset,
    ),
  );

  /// Finds or creates the person [email] in this application and grants
  /// them [roleId] in [organizationId] (`POST /v1/app/members/invitations`);
  /// a new account gets the invitation email. Needs a recent strong sign-in:
  /// fails with [StepUpRequired] past it — call [stepUp], then this again.
  /// Fails with [DelegationDenied] when a delegation rule refuses.
  Future<Result<MemberInvitation, LoginFlowError>> inviteMember({
    required String organizationId,
    required String email,
    required String roleId,
    String? firstName,
    String? lastName,
    DateTime? expiresAt,
  }) => _withLoginFlowToken(
    (token) => _appMembers.invite(
      bearerToken: token,
      organizationId: organizationId,
      email: email,
      roleId: roleId,
      firstName: firstName,
      lastName: lastName,
      expiresAt: expiresAt,
    ),
  );

  /// Grants [roleId] in [organizationId] to the member [principalId]
  /// (`POST /v1/app/members/{principal_id}/assignments`). Same step-up and
  /// refusals as [inviteMember].
  Future<Result<MemberAssignment, LoginFlowError>> grantRole({
    required String organizationId,
    required String principalId,
    required String roleId,
    DateTime? expiresAt,
  }) => _withLoginFlowToken(
    (token) => _appMembers.grant(
      bearerToken: token,
      organizationId: organizationId,
      principalId: principalId,
      roleId: roleId,
      expiresAt: expiresAt,
    ),
  );

  /// Revokes the assignment [assignmentId]
  /// (`DELETE /v1/app/members/assignments/{assignment_id}`); offer it only
  /// when [MemberAssignment.manageable]. Same step-up and refusals as
  /// [inviteMember].
  Future<Result<void, LoginFlowError>> revokeAssignment(String assignmentId) =>
      _withLoginFlowToken(
        (token) =>
            _appMembers.revoke(bearerToken: token, assignmentId: assignmentId),
      );

  /// Starts changing the signed-in person's email to [newEmail]
  /// (`POST /v1/app/email-change`, `doc/server-contract.md` §19): a code goes
  /// to [newEmail] and, when [EmailChangeStarted.confirmCurrent], another to
  /// the current address. Fails with [StepUpRequired] when the sign-in is
  /// not what the account needs ([StepUpRequirement.isStrongRequired]: a
  /// second factor; otherwise only a recent sign-in) — call [stepUp], then
  /// this again. Fails with [InvalidEmailAddress] and [RateLimited].
  Future<Result<EmailChangeStarted, LoginFlowError>> startEmailChange(
    String newEmail,
  ) => _withLoginFlowToken(
    (token) => _emailChange.start(bearerToken: token, newEmail: newEmail),
  );

  /// Confirms the change with the [code] sent to the new address and, when
  /// the start said [EmailChangeStarted.confirmCurrent], the [currentCode]
  /// sent to the current one (`POST /v1/app/email-change/confirm`). Fails
  /// with [InvalidEmailChangeCode], the same for every refusal.
  ///
  /// On success the session is refreshed so its ID token carries the new
  /// email: a new [SignedIn] is emitted with it. The server ended every
  /// other session of the person; this one continues.
  Future<Result<EmailChangeConfirmed, LoginFlowError>> confirmEmailChange(
    String code, {
    String? currentCode,
  }) async {
    final confirmed = await _withLoginFlowToken(
      (token) => _emailChange.confirm(
        bearerToken: token,
        code: code,
        currentCode: currentCode,
      ),
    );
    if (confirmed case Ok()) {
      await _refreshIdentity();
    }
    return confirmed;
  }

  /// A refresh of the session's own token queued behind every refresh in
  /// flight — those started before the change and carry the old profile —
  /// whose ID token re-reads the profile. The change is already done on the
  /// server, so a failed refresh is only logged: the next one shows it.
  Future<void> _refreshIdentity() async {
    final generation = _generation;
    final refreshed = await _queued(() => _refresh(generation));
    if (refreshed case Err(:final error)) {
      Log.w(
        'The session was not refreshed after an email change: '
        '${error.message}',
      );
    }
  }

  /// Runs [call] with LoginFlow's own token ([_loginFlowAccessToken]), the
  /// only one the members and email-change APIs accept.
  Future<Result<T, LoginFlowError>> _withLoginFlowToken<T>(
    Future<Result<T, LoginFlowError>> Function(String token) call,
  ) async {
    final tokenResult = await _loginFlowAccessToken();
    if (tokenResult case Err(:final error)) {
      return Err(error);
    }
    return call(tokenResult.data);
  }

  /// The `resource` that asks for LoginFlow's own token (`aud` = the
  /// issuer, no permissions), valid for every sign-in client
  /// (`doc/server-contract.md` §18).
  String get _loginFlowResource => config.issuer.toString();

  /// LoginFlow's own access token, asked with `resource=<issuer>` on the
  /// session's refresh family and DPoP key, and cached until shortly before
  /// it expires. The session's own token is not used: for a client with
  /// exactly one API its `aud` is that API, which the members API refuses
  /// (`wrong_audience`).
  Future<Result<String, LoginFlowError>> _loginFlowAccessToken() async {
    final session = _session;
    if (session == null) {
      return Err(const NotSignedIn());
    }
    final fresh = session.freshLoginFlowToken(_clock.now());
    if (fresh != null) {
      return Ok(fresh);
    }
    return _refreshFor(_loginFlowResource);
  }

  /// Reports the response to a request authorized with
  /// [authorizedHeadersFor]: caches its `DPoP-Nonce` (the header, when
  /// present) for the next proof to that server, and returns `true` when the
  /// server refused the request for a missing or stale nonce (`401` with
  /// `WWW-Authenticate: DPoP error="use_dpop_nonce"`, RFC 9449 §9). Then send
  /// the request once more with a NEW [authorizedHeadersFor]; never
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

  /// Signs out at [scope]: this app (revokes its refresh token), the device
  /// session (every app sharing it), the browser session (RP-initiated
  /// logout) or everywhere. The local session always ends; see
  /// `doc/server-contract.md` §9–§12.
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

  /// Closes [states]. The instance is unusable afterwards.
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
    final refreshed = await _refreshFor(null);
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
    String? organization,
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
      organization: organization,
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
      return input is AccessCodeInput
          ? _abandon(_accessCodeFailure(error))
          : Err(error);
    }
    final sent = attempt.copyWith(isAuthorizationSent: true);
    _attempt = sent;
    if (input is AccessCodeInput && response.data is! ChallengeCodeIssued) {
      // One leg by contract: a step or a browser hand-off means the server
      // did not take the `access_code` method at all.
      return _abandon(const AccessCodesUnavailable());
    }
    return switch (response.data) {
      final ChallengeStepRequired step => _onStepRequired(sent, step),
      final ChallengeCodeIssued issued => _redeemCode(
        discovery,
        code: issued.authorizationCode,
        codeVerifier: attempt.pkce.codeVerifier,
        nonce: attempt.nonce,
        // The server binds a challenge code to the `redirect_uri` of the
        // opening request (sent above), so the redemption presents that same
        // one. An access code is redeemed outside the login transaction and
        // its code carries none (`doc/server-contract.md` §16).
        redirectUri: input is AccessCodeInput ? null : config.redirectUri,
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

  /// The typed error of a refused access-code redemption
  /// (`doc/server-contract.md` §16); anything else (network, DPoP, an
  /// unknown client) is reported as it came.
  LoginFlowError _accessCodeFailure(LoginFlowError error) => switch (error) {
    RateLimited(:final retryAfter) => AccessCodeThrottled(
      retryAfter: retryAfter,
    ),
    OAuthProtocolError(code: 'slow_down') => const AccessCodeThrottled(),
    OAuthProtocolError(code: 'invalid_grant') => const InvalidAccessCode(),
    OAuthProtocolError(code: 'access_codes_disabled') =>
      const AccessCodesUnavailable(),
    _ => error,
  };

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
    if (step.stepError != null) {
      // The server refused the assertion just sent (`doc/server-contract.md`
      // §5.7): a WebAuthn challenge is single-use, so the ceremony is never
      // run again on this step.
      return _abandon(const PasskeyRejected());
    }
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
    // A step-up opened on the stored auth_session the server cannot trace back
    // to a live session (it came from a browser or hosted flow): retry once,
    // identifying the user with the ID token instead (server contract §5.2).
    final idToken = _session?.stored.idToken;
    if (sent.purpose == ChallengePurpose.stepUp &&
        sent.idTokenHint == null &&
        idToken != null) {
      return _startAttempt(
        purpose: ChallengePurpose.stepUp,
        loginHint: sent.loginHint,
        acrValues: sent.acrValues,
        maxAge: sent.maxAge,
        idTokenHint: idToken,
        organization: sent.organization,
      );
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
      organization: attempt.organization,
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
      organizationId: _attempt?.organization,
    );
    _generation++;
    _refreshing.clear();
    _refreshQueue = Future<void>.value();
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
      sessionToken: IssuedAccessToken.issued(
        value: response.accessToken,
        now: _clock.now(),
        expiresIn: response.expiresIn,
      ),
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

  /// The refresh that renews the token of [api] (`null`: the session's own
  /// token): the one in flight, or a new one queued behind any other.
  Future<Result<String, LoginFlowError>> _refreshFor(String? api) {
    final inFlight = _refreshing[api];
    if (inFlight != null) {
      return inFlight;
    }
    final generation = _generation;
    late final Future<Result<String, LoginFlowError>> refresh;
    refresh = _queued(() => _refresh(generation, api: api)).whenComplete(
      () => _refreshing.removeWhere(
        (target, inFlight) => target == api && identical(inFlight, refresh),
      ),
    );
    _refreshing[api] = refresh;
    return refresh;
  }

  /// Runs [refresh] after every refresh queued before it.
  Future<Result<String, LoginFlowError>> _queued(
    Future<Result<String, LoginFlowError>> Function() refresh,
  ) {
    final queued = _refreshQueue.then((_) => refresh());
    _refreshQueue = queued.then<void>((_) {}, onError: (Object _) {});
    return queued;
  }

  /// Rotates the refresh token for a new access token: for [api] when given
  /// (`resource`, RFC 8707), the session's own otherwise, and with
  /// [organization] made the active organization of the family.
  Future<Result<String, LoginFlowError>> _refresh(
    int generation, {
    String? api,
    String? organization,
  }) async {
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
        resource: api,
        organization: organization,
      ),
    );
    return response.when(
      ok: (tokens) => _acceptRefresh(
        discovery,
        session,
        tokens,
        generation,
        api: api,
        organization: organization,
      ),
      err: (error) => _refreshFailed(
        error,
        generation,
        api: api,
        organization: organization,
      ),
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
    int generation, {
    required String? api,
    required String? organization,
  }) async {
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
      organizationId: organization,
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
    final updated = _withRefreshedToken(
      session.copyWith(stored: stored, identity: identity),
      IssuedAccessToken.issued(
        value: response.accessToken,
        now: _clock.now(),
        expiresIn: response.expiresIn,
      ),
      api: api,
      hasSwitchedOrganization: organization != null,
    );
    _session = updated;
    final deviceSecret = response.deviceSecret;
    if (deviceSecret != null && idToken != null) {
      await _writeSsoEntry(deviceSecret: deviceSecret, idToken: idToken);
    } else if (deviceSecret != null) {
      Log.w('Ignoring a device_secret issued without its ID token.');
    }
    final public = updated.toPublic();
    if (public != session.toPublic()) {
      _emit(SignedIn(session: public));
    }
    return Ok(response.accessToken);
  }

  /// [session] holding [token] where it belongs: the token of [api], or the
  /// session's own. A switched organization drops every API token, all of
  /// them issued for the previous one.
  ActiveSession _withRefreshedToken(
    ActiveSession session,
    IssuedAccessToken token, {
    required String? api,
    required bool hasSwitchedOrganization,
  }) {
    if (hasSwitchedOrganization) {
      return ActiveSession(
        stored: session.stored,
        identity: session.identity,
        sessionToken: token,
      );
    }
    if (api == _loginFlowResource) {
      return session.copyWith(loginFlowToken: token);
    }
    if (api != null) {
      return session.withApiToken(api, token);
    }
    return session.copyWith(sessionToken: token);
  }

  Future<Result<String, LoginFlowError>> _refreshFailed(
    LoginFlowError error,
    int generation, {
    required String? api,
    required String? organization,
  }) async {
    if (!_isCurrent(generation)) {
      Log.w('Ignoring the failure of a refresh whose session already ended.');
      return Err(error);
    }
    if (error case OAuthProtocolError(code: 'invalid_target')
        when api != null) {
      Log.w('The server issues no token for the API $api to this client.');
      return Err(InvalidTarget(api: api));
    }
    if (error case OAuthProtocolError(code: 'invalid_grant')
        when organization != null) {
      // An explicit switch the server refused without revoking the family
      // (`doc/server-contract.md` §17): the session keeps its organization.
      // Were the family revoked, the next refresh says so and signs out.
      return Err(OrganizationUnavailable(organizationId: organization));
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
        organization: _session?.stored.organizationId,
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
    final token = await _sessionAccessToken();
    if (token case Err(:final error)) {
      if (error is SessionRevoked) {
        await _deleteSsoEntry();
        return Ok(_state);
      }
      return Err(error);
    }
    final ended = await _sessionLogout.endSessions(endpoint, token.data);
    if (ended case Err(error: OAuthProtocolError(code: 'invalid_token'))) {
      // The server no longer accepts this session's token: it already
      // ended (another app's device logout, a global logout, an
      // administrator). Nothing is left to end with it, and keeping the
      // local session would only fail at the next refresh.
      Log.w('The session already ended on the server; clearing it locally.');
      await _deleteSsoEntry();
      await _endLocalSession(SignOutReason.sessionRevoked);
      return Ok(_state);
    }
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
    _refreshing.clear();
    _refreshQueue = Future<void>.value();
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
