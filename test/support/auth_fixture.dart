import 'package:http/http.dart' as http;
import 'package:loginflow_auth/loginflow_auth_core.dart';
import 'package:loginflow_auth/src/core/dpop/dpop_key_store.dart';

import 'fake_apple_source.dart';
import 'fake_browser.dart';
import 'fake_facebook_source.dart';
import 'fake_google_source.dart';
import 'fake_login_flow_server.dart';
import 'fake_passkey_authenticator.dart';
import 'test_clock.dart';
import 'test_dpop_key_store.dart';

/// One "app" wired to the fake server: its own stores, browser and clock.
class AuthFixture {
  AuthFixture._({
    required this.auth,
    required this.sessionStore,
    required this.browser,
    required this.clock,
    required this.google,
    required this.apple,
    required this.facebook,
    required this.passkey,
  });

  factory AuthFixture.create(
    FakeLoginFlowServer server, {
    String clientId = 'app-one',
    SsoStore? ssoStore,
    SessionStore? sessionStore,
    FakeGoogleSource? google,
    FakeAppleSource? apple,
    FakeFacebookSource? facebook,
    FakePasskeyAuthenticator? passkey,
    bool hasBrowser = true,
    bool enableDpop = false,
    DpopKeyStore? dpopKeyStore,
  }) {
    final store = sessionStore ?? InMemorySessionStore();
    final browser = FakeBrowser(server);
    final clock = TestClock();
    final auth = LoginFlowAuth(
      config: LoginFlowConfig(
        issuer: server.issuer,
        clientId: clientId,
        scopes: const <String>['profile', 'email'],
        redirectUri: Uri.parse('https://app.example.com/oauth/callback'),
        postLogoutRedirectUri: Uri.parse('https://app.example.com/signed-out'),
        uiLocales: const <String>['es', 'en'],
        enableDpop: enableDpop,
      ),
      httpClient: http.Client(),
      sessionStore: store,
      pendingAuthorizationStore: InMemoryPendingAuthorizationStore(),
      ssoStore: ssoStore,
      userAgent: hasBrowser ? browser : null,
      googleIdTokenSource: google,
      appleTokenSource: apple,
      facebookTokenSource: facebook,
      passkeyAuthenticator: passkey,
      dpopKeyStore: enableDpop ? dpopKeyStore ?? TestDpopKeyStore() : null,
      clock: clock,
    );
    return AuthFixture._(
      auth: auth,
      sessionStore: store,
      browser: browser,
      clock: clock,
      google: google,
      apple: apple,
      facebook: facebook,
      passkey: passkey,
    );
  }

  final LoginFlowAuth auth;
  final SessionStore sessionStore;
  final FakeBrowser browser;
  final TestClock clock;
  final FakeGoogleSource? google;
  final FakeAppleSource? apple;
  final FakeFacebookSource? facebook;
  final FakePasskeyAuthenticator? passkey;

  Future<StoredSession?> storedSession() async => (await sessionStore.read())
      .when(ok: (stored) => stored, err: (_) => null);
}
