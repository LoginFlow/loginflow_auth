import 'package:flutter/foundation.dart';
import 'package:logger_rs/logger_rs.dart';
import 'package:loginflow_auth/src/core/browser/external_user_agent.dart';
import 'package:loginflow_auth/src/core/browser/in_memory_pending_authorization_store.dart';
import 'package:loginflow_auth/src/core/browser/pending_authorization_store.dart';
import 'package:loginflow_auth/src/core/config/login_flow_config.dart';
import 'package:loginflow_auth/src/core/dpop/dpop_key_store.dart';
import 'package:loginflow_auth/src/core/sso/sso_store.dart';
import 'package:loginflow_auth/src/core/storage/in_memory_session_store.dart';
import 'package:loginflow_auth/src/core/storage/session_store.dart';
import 'package:loginflow_auth/src/core/webauthn/passkey_authenticator.dart';
import 'package:loginflow_auth/src/platform/linux/linux_dpop_key_store.dart';
import 'package:loginflow_auth/src/platform/linux/linux_session_store.dart';
import 'package:loginflow_auth/src/platform/linux/loopback_user_agent.dart';
import 'package:loginflow_auth/src/platform/native/native_dpop_key_store.dart';
import 'package:loginflow_auth/src/platform/native/native_session_store.dart';
import 'package:loginflow_auth/src/platform/native/native_sso_store.dart';
import 'package:loginflow_auth/src/platform/native/native_user_agent.dart';
import 'package:loginflow_auth/src/platform/native_sso_options.dart';
import 'package:loginflow_auth/src/platform/webauthn/corbado_passkey_authenticator.dart';
import 'package:loginflow_auth/src/platform/webauthn/unsupported_platform_passkey_authenticator.dart';

/// Storage, browser, DPoP key and passkeys for every non-web target
/// (selected by conditional import).
///
/// - iOS, Android, macOS: the library's own plugin (Keychain/Keystore,
///   ASWebAuthenticationSession/Custom Tabs, Secure Enclave/Keystore keys)
///   and Corbado passkeys.
/// - Linux: the Secret Service keyring, the system browser with a loopback
///   redirect, a software DPoP key in the keyring, and no passkeys.
/// - Windows: no secure storage or browser implementation in this version:
///   the session lives in memory and browser steps report
///   `BrowserFailed(unavailable)`; this is logged once, not hidden.
class PlatformBindings {
  factory PlatformBindings({
    required LoginFlowConfig config,
    required NativeSsoOptions? nativeSso,
    required bool prefersEphemeralBrowserSession,
  }) => switch (defaultTargetPlatform) {
    TargetPlatform.android ||
    TargetPlatform.iOS ||
    TargetPlatform.macOS => PlatformBindings._(
      sessionStore: NativeSessionStore(
        issuer: config.issuer.toString(),
        clientId: config.clientId,
        sharedAccessGroup: nativeSso?.appleAccessGroup,
      ),
      pendingAuthorizationStore: InMemoryPendingAuthorizationStore(),
      ssoStore: nativeSso == null ? null : NativeSsoStore(options: nativeSso),
      userAgent: NativeUserAgent(
        prefersEphemeralSession: prefersEphemeralBrowserSession,
      ),
      dpopKeyStore: NativeDpopKeyStore(clientId: config.clientId),
      hasPasskeyApi: true,
    ),
    TargetPlatform.linux => PlatformBindings._linux(config, nativeSso),
    TargetPlatform.fuchsia ||
    TargetPlatform.windows => PlatformBindings._inMemory(),
  };

  factory PlatformBindings._linux(
    LoginFlowConfig config,
    NativeSsoOptions? nativeSso,
  ) {
    if (nativeSso != null) {
      Log.i('Native SSO options are ignored on Linux.');
    }
    return PlatformBindings._(
      sessionStore: LinuxSessionStore(
        issuer: config.issuer.toString(),
        clientId: config.clientId,
      ),
      pendingAuthorizationStore: InMemoryPendingAuthorizationStore(),
      userAgent: const LoopbackUserAgent(),
      dpopKeyStore: LinuxDpopKeyStore(clientId: config.clientId),
      hasPasskeyApi: false,
    );
  }

  factory PlatformBindings._inMemory() {
    Log.w(
      'loginflow_auth has no secure storage or system browser on '
      '${defaultTargetPlatform.name}; the session is kept in memory.',
    );
    return PlatformBindings._(
      sessionStore: InMemorySessionStore(),
      pendingAuthorizationStore: InMemoryPendingAuthorizationStore(),
      hasPasskeyApi: defaultTargetPlatform == TargetPlatform.windows,
    );
  }

  const PlatformBindings._({
    required this.sessionStore,
    required this.pendingAuthorizationStore,
    required this.hasPasskeyApi,
    this.ssoStore,
    this.userAgent,
    this.dpopKeyStore,
  });

  final SessionStore sessionStore;
  final PendingAuthorizationStore pendingAuthorizationStore;
  final SsoStore? ssoStore;
  final ExternalUserAgent? userAgent;
  final DpopKeyStore? dpopKeyStore;

  /// Whether the OS offers a passkey (WebAuthn) API the `passkeys` plugin
  /// implements.
  final bool hasPasskeyApi;

  /// The default passkey adapter: Corbado's `passkeys` where the OS has a
  /// passkey API, otherwise one that reports `notSupported` without
  /// throwing.
  PasskeyAuthenticator get passkeyAuthenticator => hasPasskeyApi
      ? CorbadoPasskeyAuthenticator()
      : const UnsupportedPlatformPasskeyAuthenticator();
}
