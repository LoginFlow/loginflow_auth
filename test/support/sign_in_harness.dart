import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loginflow_auth/loginflow_auth.dart';

import 'fake_browser.dart';
import 'fake_google_source.dart';
import 'fake_login_flow_server.dart';
import 'fake_passkey_authenticator.dart';

/// Wires a [LoginFlowAuth] to an in-memory fake server and installs it in
/// the sign-in UI, like an app's composition root does.
class SignInHarness {
  SignInHarness._(this.auth, this.server);

  factory SignInHarness.install(
    FakeLoginFlowServer server,
    SignInConfiguration configuration, {
    String clientId = 'app-one',
    SsoStore? ssoStore,
    FakeGoogleSource? google,
    FakePasskeyAuthenticator? passkey,
    LoginFlowClock clock = const SystemLoginFlowClock(),
  }) {
    final auth = LoginFlowAuth(
      config: LoginFlowConfig(
        issuer: server.issuer,
        clientId: clientId,
        redirectUri: Uri.parse('https://app.example.com/oauth/callback'),
      ),
      httpClient: server.client,
      sessionStore: InMemorySessionStore(),
      pendingAuthorizationStore: InMemoryPendingAuthorizationStore(),
      ssoStore: ssoStore,
      userAgent: FakeBrowser(server),
      googleIdTokenSource: google,
      passkeyAuthenticator: passkey,
      clock: clock,
    );
    LoginFlowSignInSetup.install(auth: auth, configuration: configuration);
    return SignInHarness._(auth, server);
  }

  final LoginFlowAuth auth;
  final FakeLoginFlowServer server;
  final List<LoginFlowSession> signedIn = <LoginFlowSession>[];

  /// Pumps the public widget inside a MaterialApp at [size] and [locale].
  Future<void> pump(
    WidgetTester tester, {
    Size size = const Size(400, 800),
    Locale locale = const Locale('en'),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await auth.initialize();
    await tester.pumpWidget(
      MaterialApp(
        locale: locale,
        supportedLocales: const [Locale('en'), Locale('es')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        home: LoginFlowSignIn(onSignedIn: signedIn.add),
      ),
    );
    await tester.pumpAndSettle();
  }
}
