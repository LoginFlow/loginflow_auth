import 'package:http/http.dart' as http;
import 'package:loginflow_auth/src/core/config/login_flow_config.dart';
import 'package:loginflow_auth/src/core/login_flow_auth.dart';
import 'package:loginflow_auth/src/core/upstream/google_id_token_source.dart';
import 'package:loginflow_auth/src/core/upstream/upstream_token_source.dart';
import 'package:loginflow_auth/src/core/webauthn/passkey_authenticator.dart';
import 'package:loginflow_auth/src/platform/bindings/native_platform_bindings.dart'
    if (dart.library.js_interop) 'package:loginflow_auth/src/platform/bindings/web_platform_bindings.dart';
import 'package:loginflow_auth/src/platform/native_sso_options.dart';
import 'package:loginflow_auth/src/platform/webauthn/corbado_passkey_authenticator.dart';

/// Builds a [LoginFlowAuth] wired to the current platform's secure storage,
/// shared SSO storage, system browser and passkeys.
abstract final class LoginFlowPlatform {
  /// [nativeSso] enables OpenID Connect Native SSO with the publisher's
  /// other apps (ignored on the web and on Linux).
  ///
  /// Passkeys work out of the box: when [passkeyAuthenticator] is not
  /// given, this method wires [CorbadoPasskeyAuthenticator] — an app does
  /// not have to write any platform code for it. On Linux, which has no
  /// passkey API, passkey ceremonies fail as
  /// `PasskeyFailed(reason: notSupported)` instead. Set [enablePasskeys] to
  /// `false` for an app that does not offer passkeys, or pass your own
  /// [passkeyAuthenticator] (a test double, or a different provider) to
  /// override the default outright.
  ///
  /// [googleIdTokenSource], [appleTokenSource] and [facebookTokenSource]
  /// have no default here: their real adapters (`NativeGoogleIdTokenSource`,
  /// `NativeAppleTokenSource`, `NativeFacebookTokenSource`) live in the
  /// separate `loginflow_auth_google`, `loginflow_auth_apple` and
  /// `loginflow_auth_facebook` packages, which depend on `loginflow_auth` —
  /// this package cannot depend back on them without a cycle. An app that
  /// offers one of those providers adds the matching package and passes its
  /// adapter here (see the main README's provider sections); without one,
  /// the matching `signInWith…` falls back to the hosted page in the system
  /// browser.
  static LoginFlowAuth createAuth({
    required LoginFlowConfig config,
    NativeSsoOptions? nativeSso,
    GoogleIdTokenSource? googleIdTokenSource,
    UpstreamTokenSource? appleTokenSource,
    UpstreamTokenSource? facebookTokenSource,
    bool enablePasskeys = true,
    PasskeyAuthenticator? passkeyAuthenticator,
    bool prefersEphemeralBrowserSession = false,
    http.Client? httpClient,
  }) {
    final bindings = PlatformBindings(
      config: config,
      nativeSso: nativeSso,
      prefersEphemeralBrowserSession: prefersEphemeralBrowserSession,
    );
    return LoginFlowAuth(
      config: config,
      httpClient: httpClient ?? http.Client(),
      sessionStore: bindings.sessionStore,
      pendingAuthorizationStore: bindings.pendingAuthorizationStore,
      ssoStore: bindings.ssoStore,
      userAgent: bindings.userAgent,
      googleIdTokenSource: googleIdTokenSource,
      appleTokenSource: appleTokenSource,
      facebookTokenSource: facebookTokenSource,
      passkeyAuthenticator:
          passkeyAuthenticator ??
          (enablePasskeys ? bindings.passkeyAuthenticator : null),
      dpopKeyStore: config.enableDpop ? bindings.dpopKeyStore : null,
    );
  }
}
