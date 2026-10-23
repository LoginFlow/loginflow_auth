// TEST_CHARTER
// Requirement: the bundled sign-in UI offers a working "Continue with a
// passkey" button when `SignInConfiguration.isPasskeySignInOffered` is set,
// and a screen for `temporary_access_pass` when the server asks for one —
// not just the underlying `LoginFlowAuth` API (`passkey_sign_in_test.dart`
// already covers that).
// Oracle: tapping the real button drives the real `SignInViewModel` against
// the fake server's real dispatch, ending in `onSignedIn`.
// Risk edge: a single-method configuration (most apps) skips the method
// picker entirely (`_entryState`) — the passkey button must still appear on
// that single-method screen, not only on the multi-method picker.
// Layer: widget test (`flutter_test`), the real risk here is UI wiring
// (button → ViewModel → `LoginFlowAuth`), not the protocol itself.
// Counterfactual: a wrong passkey (fed through a `FakePasskeyAuthenticator`
// configured with an unknown credential id) must NOT call `onSignedIn`.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loginflow_auth/loginflow_auth.dart';
import 'package:loginflow_auth/src/sign_in/ui/sign_in_keys.dart';

import '../support/fake_login_flow_server.dart';
import '../support/fake_passkey_authenticator.dart';
import '../support/sign_in_harness.dart';
import '../support/test_signing_keys.dart';

// TEST_CHARTER (added for the login-options passkey policy gating)
// Requirement: `GET /oauth2/login-options` is the source of truth for
// whether a passkey may be the first factor (`passkey`/`passkey_mode`,
// `doc/server-contract.md` §4) — the app's own
// `isPasskeySignInOffered` may only hide what the server allows, never show
// what it does not.
// Oracle: the real "Continue with a passkey" button, found by key, on the
// widget tree the ViewModel renders from the fake server's real response.
// Risk edge: `passkey_mode: "mfa_only"` must hide the FIRST-FACTOR button
// specifically — it must not be confused with `passkey: false` (disabled
// entirely); both must hide the button, for different reasons.
// Layer: widget test — the risk is the wiring from the parsed
// `ClientLoginOptions` through the ViewModel into what the picker renders.
// Counterfactual: asserting `findsNothing` only proves something; flipping
// the fake server back to `passwordless` in the same test proves the
// button's absence was caused by the policy, not by a wiring break that
// hides it unconditionally.

void main() {
  late TestSigningKeys keys;
  late FakeLoginFlowServer server;

  setUpAll(() => keys = TestSigningKeys.generate());

  setUp(() => server = FakeLoginFlowServer.inMemory(keys));

  group('Passkey button', () {
    testWidgets('appears on a single-method screen and signs in on tap', (
      tester,
    ) async {
      final passkey = FakePasskeyAuthenticator();
      final harness = SignInHarness.install(
        server,
        const SignInConfiguration(
          methods: <AuthMethod>[PasswordMethod()],
          isPasskeySignInOffered: true,
        ),
        passkey: passkey,
      );

      await harness.pump(tester);
      expect(find.byKey(SignInKeys.passwordField), findsOneWidget);
      expect(find.byKey(SignInKeys.passkeyButton), findsOneWidget);

      await tester.tap(find.byKey(SignInKeys.passkeyButton));
      await tester.pumpAndSettle();

      expect(harness.signedIn.single.identity.subject, 'cu_ana');
    });

    testWidgets('is absent when the app hides it locally', (tester) async {
      final harness = SignInHarness.install(
        server,
        const SignInConfiguration(
          methods: <AuthMethod>[PasswordMethod()],
          isPasskeySignInOffered: false,
        ),
      );

      await harness.pump(tester);

      expect(find.byKey(SignInKeys.passkeyButton), findsNothing);
    });

    testWidgets('an unrecognized credential does not sign in', (tester) async {
      final passkey = FakePasskeyAuthenticator(credentialId: 'not-enrolled');
      final harness = SignInHarness.install(
        server,
        const SignInConfiguration(
          methods: <AuthMethod>[PasswordMethod()],
          isPasskeySignInOffered: true,
        ),
        passkey: passkey,
      );

      await harness.pump(tester);
      await tester.tap(find.byKey(SignInKeys.passkeyButton));
      await tester.pumpAndSettle();

      expect(harness.signedIn, isEmpty);
    });
  });

  group('Server-driven passkey policy', () {
    testWidgets(
      'mfa_only hides the first-factor button; passwordless shows it',
      (tester) async {
        server.passkeyMode = PasskeyMode.mfaOnly;
        final harness = SignInHarness.install(
          server,
          const SignInConfiguration(methods: <AuthMethod>[PasswordMethod()]),
        );

        await harness.pump(tester);
        expect(find.byKey(SignInKeys.passkeyButton), findsNothing);

        server.passkeyMode = PasskeyMode.passwordless;
        final allowed = SignInHarness.install(
          FakeLoginFlowServer.inMemory(keys)
            ..passkeyMode = PasskeyMode.passwordless,
          const SignInConfiguration(methods: <AuthMethod>[PasswordMethod()]),
        );

        await allowed.pump(tester);
        expect(find.byKey(SignInKeys.passkeyButton), findsOneWidget);
      },
    );

    testWidgets('disabled (passkey: false) hides the button entirely', (
      tester,
    ) async {
      server.hasPasskey = false;
      final harness = SignInHarness.install(
        server,
        const SignInConfiguration(methods: <AuthMethod>[PasswordMethod()]),
      );

      await harness.pump(tester);

      expect(find.byKey(SignInKeys.passkeyButton), findsNothing);
    });
  });

  group('Temporary Access Pass', () {
    testWidgets('appears only when offered, and signs in on a valid code', (
      tester,
    ) async {
      final hidden = SignInHarness.install(
        server,
        const SignInConfiguration(methods: <AuthMethod>[PasswordMethod()]),
      );
      await hidden.pump(tester);
      expect(find.text('Use a temporary access pass'), findsNothing);

      final harness = SignInHarness.install(
        FakeLoginFlowServer.inMemory(keys),
        const SignInConfiguration(
          methods: <AuthMethod>[PasswordMethod()],
          isTemporaryAccessPassOffered: true,
        ),
      );
      await harness.pump(tester);

      await tester.tap(find.text('Use a temporary access pass'));
      await tester.pumpAndSettle();
      expect(find.byKey(SignInKeys.temporaryAccessPassStep), findsOneWidget);

      await tester.enterText(
        find.byKey(SignInKeys.emailField),
        'ana@example.com',
      );
      await tester.enterText(
        find.byKey(SignInKeys.codeField),
        FakeLoginFlowServer.temporaryAccessPassCode,
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Verify'));
      await tester.pumpAndSettle();

      expect(harness.signedIn.single.identity.subject, 'cu_ana');
    });
  });
}
