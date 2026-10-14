import 'package:http/http.dart' as http;
import 'package:loginflow_auth/src/core/config/login_flow_config.dart';
import 'package:loginflow_auth/src/core/login_flow_auth.dart';
import 'package:loginflow_auth/src/core/upstream/google_id_token_source.dart';
import 'package:loginflow_auth/src/platform/bindings/native_platform_bindings.dart'
    if (dart.library.js_interop) 'package:loginflow_auth/src/platform/bindings/web_platform_bindings.dart';
import 'package:loginflow_auth/src/platform/native_sso_options.dart';

/// Builds a [LoginFlowAuth] wired to the current platform's secure storage,
/// shared SSO storage and system browser.
abstract final class LoginFlowPlatform {
  /// [nativeSso] enables OpenID Connect Native SSO with the publisher's
  /// other apps (ignored on the web). [googleIdTokenSource] comes from the
  /// optional `loginflow_auth_google` package.
  static LoginFlowAuth createAuth({
    required LoginFlowConfig config,
    NativeSsoOptions? nativeSso,
    GoogleIdTokenSource? googleIdTokenSource,
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
    );
  }
}
