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
import 'package:loginflow_auth/src/platform/native/native_dpop_key_store.dart';
import 'package:loginflow_auth/src/platform/native/native_session_store.dart';
import 'package:loginflow_auth/src/platform/native/native_sso_store.dart';
import 'package:loginflow_auth/src/platform/native/native_user_agent.dart';
import 'package:loginflow_auth/src/platform/native_sso_options.dart';

/// Storage and browser for iOS, Android and macOS (selected by conditional
/// import on every non-web target).
///
/// Windows and Linux have no secure storage or browser implementation in
/// this version: the session lives in memory and browser steps report
/// `BrowserFailed(unavailable)`; this is logged once, not hidden.
class PlatformBindings {
  factory PlatformBindings({
    required LoginFlowConfig config,
    required NativeSsoOptions? nativeSso,
    required bool prefersEphemeralBrowserSession,
  }) {
    final isSupported = switch (defaultTargetPlatform) {
      TargetPlatform.android ||
      TargetPlatform.iOS ||
      TargetPlatform.macOS => true,
      TargetPlatform.fuchsia ||
      TargetPlatform.linux ||
      TargetPlatform.windows => false,
    };
    if (!isSupported) {
      Log.w(
        'loginflow_auth has no secure storage or system browser on '
        '${defaultTargetPlatform.name}; the session is kept in memory.',
      );
      return PlatformBindings._(
        sessionStore: InMemorySessionStore(),
        pendingAuthorizationStore: InMemoryPendingAuthorizationStore(),
      );
    }
    return PlatformBindings._(
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
    );
  }

  const PlatformBindings._({
    required this.sessionStore,
    required this.pendingAuthorizationStore,
    this.ssoStore,
    this.userAgent,
    this.dpopKeyStore,
  });

  final SessionStore sessionStore;
  final PendingAuthorizationStore pendingAuthorizationStore;
  final SsoStore? ssoStore;
  final ExternalUserAgent? userAgent;
  final DpopKeyStore? dpopKeyStore;
}
