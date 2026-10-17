import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loginflow_auth/loginflow_auth.dart';
import 'package:loginflow_auth/src/sign_in/ui/desktop/sign_in_screen_desktop.dart';
import 'package:loginflow_auth/src/sign_in/ui/mobile/sign_in_screen_mobile.dart';
import 'package:loginflow_auth/src/sign_in/ui/sign_in_keys.dart';

import '../support/fake_login_flow_server.dart';
import '../support/sign_in_harness.dart';
import '../support/test_signing_keys.dart';

void main() {
  late TestSigningKeys keys;
  late FakeLoginFlowServer server;

  setUpAll(() => keys = TestSigningKeys.generate());

  setUp(() => server = FakeLoginFlowServer.inMemory(keys));

  const allMethods = SignInConfiguration(
    methods: <AuthMethod>[
      MicrosoftMethod(),
      PasswordMethod(),
      GoogleMethod(),
      EmailOtpMethod(resendCooldown: Duration.zero),
    ],
    isSelfSignUpOffered: true,
  );

  Finder method(String wireName) => find.byKey(
    ValueKey<String>('${SignInKeys.methodButtonPrefix}.$wireName'),
  );

  Future<void> enter(WidgetTester tester, Key field, String text) =>
      tester.enterText(find.byKey(field), text);

  group('Method picker', () {
    testWidgets('renders only configured methods the server allows, in '
        'configured order', (tester) async {
      server.loginMethods = <String>['password', 'google', 'email_otp'];
      final harness = SignInHarness.install(server, allMethods);

      await harness.pump(tester);

      expect(method('microsoft'), findsNothing);
      final ordered = <String>[
        'password',
        'google',
        'email_otp',
      ].map((name) => tester.getTopLeft(method(name)).dy).toList();
      expect(ordered, orderedEquals(<double>[...ordered]..sort()));
      expect(find.text('Create an account'), findsOneWidget);
    });

    testWidgets('a method the app did not configure is never shown even if '
        'the server allows it', (tester) async {
      final harness = SignInHarness.install(
        server,
        const SignInConfiguration(
          methods: <AuthMethod>[PasswordMethod(), GoogleMethod()],
        ),
      );

      await harness.pump(tester);

      expect(method('password'), findsOneWidget);
      expect(method('google'), findsOneWidget);
      expect(method('microsoft'), findsNothing);
      expect(method('email_otp'), findsNothing);
      expect(find.text('Create an account'), findsNothing);
    });

    testWidgets('Apple and Facebook buttons appear only when the server '
        'lists them', (tester) async {
      server.loginMethods = <String>['password', 'apple'];
      final harness = SignInHarness.install(
        server,
        const SignInConfiguration(
          methods: <AuthMethod>[
            PasswordMethod(),
            AppleMethod(),
            FacebookMethod(),
          ],
        ),
      );

      await harness.pump(tester);

      expect(method('apple'), findsOneWidget);
      expect(method('facebook'), findsNothing);
      expect(find.byKey(SignInKeys.appleButton), findsOneWidget);
      expect(find.byKey(SignInKeys.facebookButton), findsNothing);
    });

    testWidgets('sign-up is hidden when the server disables it', (
      tester,
    ) async {
      server.isSelfSignUpEnabled = false;
      final harness = SignInHarness.install(server, allMethods);

      await harness.pump(tester);

      expect(find.text('Create an account'), findsNothing);
    });

    testWidgets('a single method opens directly', (tester) async {
      final harness = SignInHarness.install(
        server,
        const SignInConfiguration(methods: <AuthMethod>[PasswordMethod()]),
      );

      await harness.pump(tester);

      expect(find.byKey(SignInKeys.passwordField), findsOneWidget);
      expect(method('password'), findsNothing);
      expect(find.text('Back'), findsNothing);
    });

    testWidgets('no shared method shows the empty state', (tester) async {
      server.loginMethods = <String>['google'];
      final harness = SignInHarness.install(
        server,
        const SignInConfiguration(methods: <AuthMethod>[PasswordMethod()]),
      );

      await harness.pump(tester);

      expect(
        find.text('No sign-in method is available for this app.'),
        findsOneWidget,
      );
    });
  });

  group('Password', () {
    testWidgets('signs in and calls onSignedIn once', (tester) async {
      final harness = SignInHarness.install(server, allMethods);
      await harness.pump(tester);

      await tester.tap(method('password'));
      await tester.pumpAndSettle();
      await enter(tester, SignInKeys.emailField, 'ana@example.com');
      await enter(tester, SignInKeys.passwordField, 'correct-horse');
      await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
      await tester.pumpAndSettle();

      expect(harness.signedIn.single.identity.subject, 'cu_ana');
    });

    testWidgets('empty fields are refused before any request', (tester) async {
      final harness = SignInHarness.install(server, allMethods);
      await harness.pump(tester);
      await tester.tap(method('password'));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
      await tester.pumpAndSettle();

      expect(find.text('Enter your email'), findsOneWidget);
      expect(find.text('Enter your password'), findsOneWidget);
      expect(server.challengeRequests, isEmpty);
    });

    testWidgets('a wrong password shows the error and keeps the form', (
      tester,
    ) async {
      final harness = SignInHarness.install(server, allMethods);
      await harness.pump(tester);
      await tester.tap(method('password'));
      await tester.pumpAndSettle();

      await enter(tester, SignInKeys.emailField, 'ana@example.com');
      await enter(tester, SignInKeys.passwordField, 'nope');
      await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
      await tester.pumpAndSettle();

      expect(
        find.text('The details you entered are not correct.'),
        findsOneWidget,
      );
      expect(find.byKey(SignInKeys.passwordField), findsOneWidget);
      expect(harness.signedIn, isEmpty);
    });

    testWidgets('autofill hints are set for password managers', (tester) async {
      final harness = SignInHarness.install(server, allMethods);
      await harness.pump(tester);
      await tester.tap(method('password'));
      await tester.pumpAndSettle();

      final email = tester.widget<TextField>(find.byKey(SignInKeys.emailField));
      final password = tester.widget<TextField>(
        find.byKey(SignInKeys.passwordField),
      );
      expect(email.autofillHints, contains(AutofillHints.email));
      expect(password.autofillHints, contains(AutofillHints.password));
      expect(password.obscureText, isTrue);
    });
  });

  group('Email code', () {
    testWidgets('sends the code and signs in with it', (tester) async {
      final harness = SignInHarness.install(server, allMethods);
      await harness.pump(tester);

      await tester.tap(method('email_otp'));
      await tester.pumpAndSettle();
      await enter(tester, SignInKeys.emailField, 'ana@example.com');
      await tester.tap(find.widgetWithText(FilledButton, 'Send code'));
      await tester.pumpAndSettle();

      expect(find.text('We sent a code to ana@example.com'), findsOneWidget);
      final code = tester.widget<TextField>(find.byKey(SignInKeys.codeField));
      expect(code.autofillHints, contains(AutofillHints.oneTimeCode));

      await enter(
        tester,
        SignInKeys.codeField,
        FakeLoginFlowServer.emailOtpCode,
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Verify'));
      await tester.pumpAndSettle();

      expect(harness.signedIn.single.identity.email, 'ana@example.com');
    });

    testWidgets('resend waits for the configured cooldown', (tester) async {
      final harness = SignInHarness.install(
        server,
        const SignInConfiguration(
          methods: <AuthMethod>[
            EmailOtpMethod(resendCooldown: Duration(seconds: 3)),
          ],
        ),
      );
      await harness.pump(tester);
      await enter(tester, SignInKeys.emailField, 'ana@example.com');
      await tester.tap(find.widgetWithText(FilledButton, 'Send code'));
      await tester.pumpAndSettle();

      expect(find.text('Resend code in 3s'), findsOneWidget);
      await tester.pump(const Duration(seconds: 3));
      expect(find.text('Resend code'), findsOneWidget);

      await tester.tap(find.text('Resend code'));
      await tester.pumpAndSettle();
      expect(server.sentEmailOtps, hasLength(2));
      await tester.pump(const Duration(seconds: 3));
    });
  });

  group('TOTP', () {
    testWidgets('is asked automatically and accepts a recovery code', (
      tester,
    ) async {
      final harness = SignInHarness.install(server, allMethods);
      await harness.pump(tester);
      await tester.tap(method('password'));
      await tester.pumpAndSettle();
      await enter(tester, SignInKeys.emailField, 'tomas@example.com');
      await enter(tester, SignInKeys.passwordField, 'battery-staple');
      await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
      await tester.pumpAndSettle();

      expect(find.text('Two-step verification'), findsOneWidget);
      expect(
        find.text('Enter the 6-digit code from your authenticator app.'),
        findsOneWidget,
      );

      await tester.tap(find.text('Use a recovery code'));
      await tester.pumpAndSettle();
      expect(find.text('Enter one of your recovery codes.'), findsOneWidget);

      await enter(
        tester,
        SignInKeys.codeField,
        FakeLoginFlowServer.recoveryCode,
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Verify'));
      await tester.pumpAndSettle();

      expect(harness.signedIn.single.identity.subject, 'cu_tomas');
    });
  });

  group('Lockout', () {
    testWidgets('429 shows the lockout and returns when it ends', (
      tester,
    ) async {
      final harness = SignInHarness.install(server, allMethods);
      await harness.pump(tester);
      await tester.tap(method('password'));
      await tester.pumpAndSettle();
      server.rateLimitNextChallenge = const Duration(seconds: 2);

      await enter(tester, SignInKeys.emailField, 'ana@example.com');
      await enter(tester, SignInKeys.passwordField, 'correct-horse');
      await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
      await tester.pumpAndSettle();

      expect(find.text('Too many attempts'), findsOneWidget);
      expect(find.text('Try again in 2 seconds.'), findsOneWidget);

      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();
      expect(method('password'), findsOneWidget);
    });
  });

  group('Native SSO', () {
    testWidgets('offers "Continue as" and signs in without credentials', (
      tester,
    ) async {
      final shared = InMemorySsoStore();
      final appOne = SignInHarness.install(
        server,
        allMethods,
        ssoStore: shared,
      );
      await appOne.auth.initialize();
      await appOne.auth.signInWithPassword(
        loginHint: 'ana@example.com',
        password: 'correct-horse',
      );
      final appTwo = SignInHarness.install(
        server,
        allMethods,
        clientId: 'app-two',
        ssoStore: shared,
      );

      await appTwo.pump(tester);

      expect(find.text('Continue as Ana Ruiz'), findsOneWidget);
      await tester.tap(find.text('Continue as Ana Ruiz'));
      await tester.pumpAndSettle();
      expect(appTwo.signedIn.single.isSsoBound, isTrue);
    });
  });

  group('Localization and layout', () {
    testWidgets('Spanish texts follow the ambient locale', (tester) async {
      final harness = SignInHarness.install(server, allMethods);

      await harness.pump(tester, locale: const Locale('es'));

      expect(find.text('Iniciar sesión'), findsOneWidget);
      expect(find.text('Continuar con contraseña'), findsOneWidget);
      expect(find.text('Crear una cuenta'), findsOneWidget);
    });

    testWidgets('branded copy replaces the built-in title', (tester) async {
      final harness = SignInHarness.install(
        server,
        const SignInConfiguration(
          methods: <AuthMethod>[PasswordMethod(), GoogleMethod()],
          copy: SignInCopy(
            title: LocalizedText(english: 'Acme', spanish: 'Acme ES'),
          ),
        ),
      );

      await harness.pump(tester);

      expect(find.text('Acme'), findsOneWidget);
    });

    testWidgets('a phone in landscape keeps the mobile layout', (tester) async {
      final harness = SignInHarness.install(server, allMethods);

      await harness.pump(tester, size: const Size(800, 400));

      expect(find.byType(SignInScreenMobile), findsOneWidget);
      expect(find.byType(SignInScreenDesktop), findsNothing);
    });

    testWidgets('tablet and desktop use the centered card', (tester) async {
      final harness = SignInHarness.install(server, allMethods);

      await harness.pump(tester, size: const Size(1280, 900));

      expect(find.byType(SignInScreenDesktop), findsOneWidget);
      expect(find.byType(Card), findsOneWidget);
    });
  });

  group('Accessibility', () {
    testWidgets('tap targets and labels meet the guidelines', (tester) async {
      final semantics = tester.ensureSemantics();
      final harness = SignInHarness.install(server, allMethods);
      await harness.pump(tester);

      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));

      await tester.tap(method('password'));
      await tester.pumpAndSettle();
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      semantics.dispose();
    });
  });
}
