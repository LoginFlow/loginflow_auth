import 'package:logger_rs/logger_rs.dart';
import 'package:loginflow_auth/src/core/browser/external_user_agent.dart';
import 'package:loginflow_auth/src/core/browser/pending_authorization_store.dart';
import 'package:loginflow_auth/src/core/config/login_flow_config.dart';
import 'package:loginflow_auth/src/core/dpop/dpop_key_store.dart';
import 'package:loginflow_auth/src/core/sso/sso_store.dart';
import 'package:loginflow_auth/src/core/storage/in_memory_session_store.dart';
import 'package:loginflow_auth/src/core/storage/session_store.dart';
import 'package:loginflow_auth/src/core/webauthn/passkey_authenticator.dart';
import 'package:loginflow_auth/src/platform/native_sso_options.dart';
import 'package:loginflow_auth/src/platform/web/web_dpop_key_store.dart';
import 'package:loginflow_auth/src/platform/web/web_pending_authorization_store.dart';
import 'package:loginflow_auth/src/platform/web/web_session_store.dart';
import 'package:loginflow_auth/src/platform/web/web_user_agent.dart';
import 'package:loginflow_auth/src/platform/webauthn/corbado_passkey_authenticator.dart';

/// Flutter web: with DPoP, the key-bound session in `localStorage` and the
/// non-extractable key in IndexedDB, so a reload restores it; without DPoP,
/// tokens in memory only. The PKCE round-trip lives in `sessionStorage`, a
/// top-level redirect is the user agent, and passkeys run through the
/// browser's WebAuthn API (`passkeys_web`). Native SSO does not apply in a
/// browser; SSO comes from the authorization server's first-party session
/// cookie (`doc/decisions.md` D10).
class PlatformBindings {
  factory PlatformBindings({
    required LoginFlowConfig config,
    required NativeSsoOptions? nativeSso,
    // Same signature as the native bindings chosen by the conditional
    // import; a browser tab has no ephemeral-session switch.
    // ignore: avoid_unused_constructor_parameters
    required bool prefersEphemeralBrowserSession,
  }) {
    if (nativeSso != null) {
      Log.i('Native SSO options are ignored on the web.');
    }
    return PlatformBindings._(
      sessionStore: config.enableDpop
          ? WebSessionStore(
              key: 'loginflow_auth.session|${config.issuer}|${config.clientId}',
            )
          : InMemorySessionStore(),
      pendingAuthorizationStore: WebPendingAuthorizationStore(
        key: 'loginflow_auth.pending|${config.issuer}|${config.clientId}',
      ),
      userAgent: const WebUserAgent(),
      dpopKeyStore: WebDpopKeyStore(clientId: config.clientId),
    );
  }

  const PlatformBindings._({
    required this.sessionStore,
    required this.pendingAuthorizationStore,
    this.userAgent,
    this.dpopKeyStore,
  });

  final SessionStore sessionStore;
  final PendingAuthorizationStore pendingAuthorizationStore;
  final ExternalUserAgent? userAgent;
  final DpopKeyStore? dpopKeyStore;

  SsoStore? get ssoStore => null;

  PasskeyAuthenticator get passkeyAuthenticator =>
      CorbadoPasskeyAuthenticator();
}
