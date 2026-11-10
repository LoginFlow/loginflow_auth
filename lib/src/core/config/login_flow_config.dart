import 'package:loginflow_auth/src/core/error/login_flow_error.dart';
import 'package:loginflow_auth/src/core/http/endpoint_security.dart';
import 'package:loginflow_auth/src/core/json/json_field_reader.dart';
import 'package:loginflow_auth/src/core/json/list_equality.dart';
import 'package:result_controller/result_controller.dart';

/// How an app identifies itself to LoginFlow.
class LoginFlowConfig {
  /// Creates a [LoginFlowConfig].
  const LoginFlowConfig({
    required this.issuer,
    required this.clientId,
    this.scopes = const <String>[],
    this.apis = const <String>[],
    this.redirectUri,
    this.postLogoutRedirectUri,
    this.uiLocales = const <String>[],
    this.clockSkew = const Duration(seconds: 60),
    this.requestTimeout = const Duration(seconds: 30),
    this.enableDpop = false,
    this.emailCodeResendCooldown = defaultEmailCodeResendCooldown,
    this.passkeyRpId,
  });

  /// Reads a [LoginFlowConfig] from its JSON form ([toJson]).
  factory LoginFlowConfig.fromJson(Map<String, Object?> json) {
    final redirect = json.optionalString('redirect_uri');
    final postLogout = json.optionalString('post_logout_redirect_uri');
    return LoginFlowConfig(
      issuer: Uri.parse(json.requireString('issuer')),
      clientId: json.requireString('client_id'),
      scopes: json.stringList('scopes'),
      apis: json.stringList('apis'),
      redirectUri: redirect == null ? null : Uri.parse(redirect),
      postLogoutRedirectUri: postLogout == null ? null : Uri.parse(postLogout),
      uiLocales: json.stringList('ui_locales'),
      clockSkew: Duration(seconds: json.requireInt('clock_skew_seconds')),
      requestTimeout: Duration(
        seconds: json.requireInt('request_timeout_seconds'),
      ),
      enableDpop: json.optionalBool('enable_dpop', absent: false),
      emailCodeResendCooldown: Duration(
        seconds:
            json.optionalInt('email_code_resend_cooldown_seconds') ??
            defaultEmailCodeResendCooldown.inSeconds,
      ),
      passkeyRpId: json.optionalString('passkey_rp_id'),
    );
  }

  /// The [emailCodeResendCooldown] of a configuration that sets none.
  static const Duration defaultEmailCodeResendCooldown = Duration(seconds: 60);

  /// The issuer identifier, e.g. `LoginFlowEnvironment.production.issuer`.
  final Uri issuer;

  /// The client identifier registered for this app.
  final String clientId;

  /// Extra scopes for the app's own APIs. `openid` and `offline_access` are
  /// always requested, and `device_sso` when Native SSO is enabled.
  final List<String> scopes;

  /// The APIs this app calls, by audience (the `resource` value of
  /// RFC 8707, e.g. `APP-S0R6Y0T0X6`). Each one gets its own access token
  /// from `LoginFlowAuth.accessTokenFor`, carrying only that API's
  /// permissions; an API missing here is refused locally, before any
  /// request. Leave it empty for an app that only signs users in.
  final List<String> apis;

  /// Redirect URI for every step that needs the system browser
  /// (`redirect_to_web`, Microsoft, sign-up, web sign-in). The password
  /// reset is in-app and needs none.
  /// Prefer a claimed `https` link (RFC 8252 §7.2). Without it, browser steps
  /// fail with `BrowserFailed(unavailable)`.
  final Uri? redirectUri;

  /// Registered `post_logout_redirect_uri` for RP-initiated logout.
  final Uri? postLogoutRedirectUri;

  /// Preferred languages for server-rendered text such as the email OTP
  /// (`ui_locales`, OpenID Connect Core §3.1.2.1), most preferred first.
  final List<String> uiLocales;

  /// Tolerance applied to `exp` and `iat` checks.
  final Duration clockSkew;

  /// Upper bound for a single HTTP request.
  final Duration requestTimeout;

  /// Whether this client must prove possession of its DPoP key (RFC 9449) on
  /// every request to the token endpoint, the authorization challenge
  /// endpoint, and resource endpoints. The LoginFlow profile requires this
  /// for `native` + `first_party` clients (`doc/server-contract.md` §13).
  final bool enableDpop;

  /// The wait between two emailed sign-in codes. LoginFlow answers an
  /// email-code request the same whether or not an email left, and sends no
  /// new code for a while once one was issued; `LoginFlowAuth.resendEmailOtp`
  /// is refused locally until this wait is over, and
  /// `ChallengePrompt.resendAvailableAt` says when it is. Must be positive.
  final Duration emailCodeResendCooldown;

  /// The company's passkey relying-party ID: the host of its passkeys, the
  /// one the app's Associated Domains (`webcredentials:`) and
  /// `assetlinks.json` name, e.g. `acme-id.loginflow.dev`. A sign-in QR
  /// (`LoginFlowAuth.parseSignInQr`) is accepted only when it points at this
  /// host: a QR of another company is not this app's business. `null`
  /// leaves QR approval off; nothing else reads it.
  final String? passkeyRpId;

  /// Refuses a configuration that could leak codes or tokens: the issuer
  /// must be `https` without query or fragment, and every redirect URI must
  /// be acceptable (`doc/decisions.md` D3, D8).
  Result<LoginFlowConfig, LoginFlowError> validate() {
    if (clientId.isEmpty) {
      return Err(const ConfigurationInvalid(description: 'client_id is empty'));
    }
    if (apis.any((api) => api.trim().isEmpty) ||
        apis.toSet().length != apis.length) {
      return Err(
        const ConfigurationInvalid(
          description: 'apis has an empty or a repeated audience',
        ),
      );
    }
    if (!issuer.isValidIssuer) {
      return Err(
        const ConfigurationInvalid(
          description: 'the issuer must be https without query or fragment',
        ),
      );
    }
    if (emailCodeResendCooldown <= Duration.zero) {
      return Err(
        const ConfigurationInvalid(
          description: 'email_code_resend_cooldown must be positive',
        ),
      );
    }
    final rpId = passkeyRpId;
    if (rpId != null && !_isPlainHost(rpId)) {
      return Err(
        const ConfigurationInvalid(
          description:
              'passkey_rp_id must be a host, e.g. acme-id.loginflow.dev',
        ),
      );
    }
    final redirects = <Uri?>[redirectUri, postLogoutRedirectUri].nonNulls;
    if (!redirects.every((redirect) => redirect.isValidRedirect)) {
      return Err(
        const ConfigurationInvalid(
          description:
              'a redirect URI has a fragment, userinfo or a '
              'disallowed scheme',
        ),
      );
    }
    return Ok(this);
  }

  /// A lower-case DNS host with no scheme, port, path or user.
  static bool _isPlainHost(String value) => RegExp(
    r'^[a-z0-9]([a-z0-9-]*[a-z0-9])?(\.[a-z0-9]([a-z0-9-]*[a-z0-9])?)+$',
  ).hasMatch(value);

  /// A copy of this [LoginFlowConfig] with the given fields replaced.
  LoginFlowConfig copyWith({
    Uri? issuer,
    String? clientId,
    List<String>? scopes,
    List<String>? apis,
    Uri? redirectUri,
    Uri? postLogoutRedirectUri,
    List<String>? uiLocales,
    Duration? clockSkew,
    Duration? requestTimeout,
    bool? enableDpop,
    Duration? emailCodeResendCooldown,
    String? passkeyRpId,
  }) => LoginFlowConfig(
    issuer: issuer ?? this.issuer,
    clientId: clientId ?? this.clientId,
    scopes: scopes ?? this.scopes,
    apis: apis ?? this.apis,
    redirectUri: redirectUri ?? this.redirectUri,
    postLogoutRedirectUri: postLogoutRedirectUri ?? this.postLogoutRedirectUri,
    uiLocales: uiLocales ?? this.uiLocales,
    clockSkew: clockSkew ?? this.clockSkew,
    requestTimeout: requestTimeout ?? this.requestTimeout,
    enableDpop: enableDpop ?? this.enableDpop,
    emailCodeResendCooldown:
        emailCodeResendCooldown ?? this.emailCodeResendCooldown,
    passkeyRpId: passkeyRpId ?? this.passkeyRpId,
  );

  /// The JSON form of this [LoginFlowConfig], read back by [LoginFlowConfig.fromJson].
  Map<String, Object?> toJson() => <String, Object?>{
    'issuer': issuer.toString(),
    'client_id': clientId,
    'scopes': scopes,
    'apis': apis,
    'redirect_uri': redirectUri?.toString(),
    'post_logout_redirect_uri': postLogoutRedirectUri?.toString(),
    'ui_locales': uiLocales,
    'clock_skew_seconds': clockSkew.inSeconds,
    'request_timeout_seconds': requestTimeout.inSeconds,
    'enable_dpop': enableDpop,
    'email_code_resend_cooldown_seconds': emailCodeResendCooldown.inSeconds,
    'passkey_rp_id': ?passkeyRpId,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LoginFlowConfig &&
          issuer == other.issuer &&
          clientId == other.clientId &&
          scopes.hasSameValues(other.scopes) &&
          apis.hasSameValues(other.apis) &&
          redirectUri == other.redirectUri &&
          postLogoutRedirectUri == other.postLogoutRedirectUri &&
          uiLocales.hasSameValues(other.uiLocales) &&
          clockSkew == other.clockSkew &&
          requestTimeout == other.requestTimeout &&
          enableDpop == other.enableDpop &&
          emailCodeResendCooldown == other.emailCodeResendCooldown &&
          passkeyRpId == other.passkeyRpId;

  @override
  int get hashCode => Object.hash(
    issuer,
    clientId,
    scopes.valuesHash,
    apis.valuesHash,
    redirectUri,
    postLogoutRedirectUri,
    uiLocales.valuesHash,
    clockSkew,
    requestTimeout,
    enableDpop,
    emailCodeResendCooldown,
    passkeyRpId,
  );
}
