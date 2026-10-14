@TestOn('browser')
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:loginflow_auth/loginflow_auth_core.dart';
import 'package:loginflow_auth/src/platform/bindings/web_platform_bindings.dart';
import 'package:loginflow_auth/src/platform/native_sso_options.dart';
import 'package:web/web.dart' as web;

void main() {
  final config = LoginFlowConfig(
    issuer: LoginFlowEnvironment.development.issuer,
    clientId: 'dashboard',
    redirectUri: Uri.parse('https://dashboard.example.com/callback'),
  );

  test('tokens live in memory; Native SSO is off in the browser', () {
    final bindings = PlatformBindings(
      config: config,
      nativeSso: const NativeSsoOptions(appleAccessGroup: 'ignored'),
      prefersEphemeralBrowserSession: false,
    );

    expect(bindings.sessionStore, isA<InMemorySessionStore>());
    expect(bindings.ssoStore, isNull);
  });

  test(
    'the PKCE round-trip survives in sessionStorage and is removed',
    () async {
      final store = PlatformBindings(
        config: config,
        nativeSso: null,
        prefersEphemeralBrowserSession: false,
      ).pendingAuthorizationStore;
      final pending = PendingAuthorization(
        purpose: PendingPurpose.signIn,
        state: 'state-1',
        redirectUri: Uri.parse('https://dashboard.example.com/callback'),
        createdAt: DateTime.utc(2026, 10, 15),
        codeVerifier: 'verifier-1',
        nonce: 'nonce-1',
      );

      await store.write(pending);
      expect((await store.read()).data, pending);
      expect(web.window.localStorage.length, 0);

      await store.clear();
      expect((await store.read()).data, isNull);
    },
  );
}
