import 'package:http/http.dart' as http;
import 'package:loginflow_auth/loginflow_auth_core.dart';

import 'fake_browser.dart';
import 'fake_google_source.dart';
import 'fake_login_flow_server.dart';
import 'test_clock.dart';

/// One "app" wired to the fake server: its own stores, browser and clock.
class AuthFixture {
  AuthFixture._({
    required this.auth,
    required this.sessionStore,
    required this.browser,
    required this.clock,
    required this.google,
  });

  factory AuthFixture.create(
    FakeLoginFlowServer server, {
    String clientId = 'app-one',
    SsoStore? ssoStore,
    SessionStore? sessionStore,
    FakeGoogleSource? google,
    bool hasBrowser = true,
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
      ),
      httpClient: http.Client(),
      sessionStore: store,
      pendingAuthorizationStore: InMemoryPendingAuthorizationStore(),
      ssoStore: ssoStore,
      userAgent: hasBrowser ? browser : null,
      googleIdTokenSource: google,
      clock: clock,
    );
    return AuthFixture._(
      auth: auth,
      sessionStore: store,
      browser: browser,
      clock: clock,
      google: google,
    );
  }

  final LoginFlowAuth auth;
  final SessionStore sessionStore;
  final FakeBrowser browser;
  final TestClock clock;
  final FakeGoogleSource? google;

  Future<StoredSession?> storedSession() async => (await sessionStore.read())
      .when(ok: (stored) => stored, err: (_) => null);
}
