// Through the public widgets, against the fake server: the access-code
// field shapes what is typed (`AccessCodeInputFormatter`) and signs in;
// the passkey manager deletes a passkey only behind its confirmation.

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loginflow_auth/loginflow_auth.dart';
import 'package:loginflow_auth/src/sign_in/ui/sign_in_keys.dart';

import '../support/fake_login_flow_server.dart';
import '../support/fake_passkey_authenticator.dart';
import '../support/sign_in_harness.dart';
import '../support/test_signing_keys.dart';

void main() {
  late TestSigningKeys keys;
  late FakeLoginFlowServer server;

  setUpAll(() => keys = TestSigningKeys.generate());

  setUp(() => server = FakeLoginFlowServer.inMemory(keys));

  testWidgets('an access-code-only app opens on the code step, formats the '
      'typed code and signs the subject in', (tester) async {
    server.requiresDpop = true;
    final harness = SignInHarness.install(
      server,
      const SignInConfiguration(
        methods: <AuthMethod>[],
        isAccessCodeOffered: true,
      ),
      enableDpop: true,
    );
    await harness.pump(tester);

    await tester.enterText(find.byKey(SignInKeys.accessCodeField), 'k7m2q9px');
    await tester.pump();

    expect(find.text('K7M2-Q9PX'), findsOneWidget);

    await tester.tap(find.text('Sign in').last);
    await tester.pumpAndSettle();

    expect(harness.signedIn.single.identity.externalSubject, 'driver:7');
  });

  testWidgets('the passkey manager deletes a passkey only after the user '
      'confirms', (tester) async {
    final harness = SignInHarness.install(
      server,
      const SignInConfiguration(methods: <AuthMethod>[PasswordMethod()]),
      passkey: FakePasskeyAuthenticator(credentialId: 'credential-new-0001'),
    );
    await tester.runAsync(() async {
      await harness.auth.initialize();
      await harness.auth.signInWithPassword(
        loginHint: 'ana@example.com',
        password: 'correct-horse',
      );
      await harness.auth.enrollPasskey(
        username: 'ana@example.com',
        displayName: 'Ana Ruiz',
      );
    });
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      const MaterialApp(
        locale: Locale('en'),
        supportedLocales: [Locale('en'), Locale('es')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        home: LoginFlowPasskeys(),
      ),
    );
    await tester.pumpAndSettle();
    final delete = find.byKey(
      const ValueKey<String>(
        '${SignInKeys.passkeyDeletePrefix}.credential-new-0001',
      ),
    );
    expect(delete, findsOneWidget);

    await tester.tap(delete);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(delete, findsOneWidget);

    await tester.tap(delete);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(SignInKeys.passkeyDialogConfirm));
    await tester.pumpAndSettle();

    expect(delete, findsNothing);
    expect(find.text('You have no passkeys yet.'), findsOneWidget);
  });
}
