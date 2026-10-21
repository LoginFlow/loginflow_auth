// TEST_CHARTER
// Requirement: no passkey attempt can leave the bundled sign-in UI stuck
// busy. `SignInViewModel._run` (and the auto-suggest path) always clears
// `isBusy` and its in-flight guard — after an error, after an exception an
// adapter should never have thrown, and after a ceremony that never
// finishes on the platform (resolved by `CorbadoPasskeyAuthenticator`'s
// ceremony timeout).
// Oracle: the public `SignInState` (`isBusy`, `feedback`, `phase`) and a
// SECOND tap reaching the authenticator — the in-flight guard was released,
// not just the spinner hidden.
// Risk edge: the server sends `mediation: "conditional"` for a discoverable
// request (no remembered email); forwarded to iOS/the web without an
// autofill field, that ceremony never resolves and the old `_run` waited on
// it forever.
// Layer: ViewModel against the fake server's real dispatch, with the REAL
// Corbado adapter over a fake plugin platform for the hang case — the
// timeout lives in the adapter, so a fake `PasskeyAuthenticator` would not
// exercise it.
// Counterfactual: without try/finally the throwing adapter's exception
// escapes `signInWithPasskey` and the guard stays set (second tap ignored);
// without the adapter timeout/modal mediation the hanging case never
// completes (test timeout).
//
// TEST_CHARTER (added for the ViewModel's own bound on an in-flight action)
// Requirement: `isBusy` and the in-flight guard can never stay set, even
// when an app-supplied adapter with no timeout of its own never answers.
// Oracle: the public `SignInState` (`isBusy`, `feedback`, `phase`) once
// `SignInViewModel.actionTimeout` elapses on the fake clock, and a second
// tap reaching the authenticator.
// Risk edge: a never-completing future — not an error, not a throw — which
// neither the `Result` handling nor the try/finally ever sees.
// Layer: ViewModel against the fake server's real dispatch, inside
// `testWidgets` so the fake clock elapses the bound without waiting it.
// Counterfactual: without the timeout in `_guarded`, the state is still
// busy after the bound and the second tap is ignored.

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:loginflow_auth/loginflow_auth.dart';
import 'package:loginflow_auth/src/sign_in/model/sign_in_feedback.dart';
import 'package:loginflow_auth/src/sign_in/model/sign_in_phase.dart';
import 'package:loginflow_auth/src/sign_in/service/sign_in_service.dart';
import 'package:loginflow_auth/src/sign_in/viewmodel/sign_in_viewmodel.dart';
import 'package:passkeys/types.dart' as corbado;
import 'package:passkeys_platform_interface/passkeys_platform_interface.dart';

import '../support/fake_login_flow_server.dart';
import '../support/fake_passkeys_platform.dart';
import '../support/hanging_passkey_authenticator.dart';
import '../support/sign_in_harness.dart';
import '../support/test_signing_keys.dart';
import '../support/throwing_passkey_authenticator.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late TestSigningKeys keys;
  late FakeLoginFlowServer server;

  setUpAll(() => keys = TestSigningKeys.generate());

  setUp(() => server = FakeLoginFlowServer.inMemory(keys));

  SignInViewModel viewModel() => SignInService.flow.notifier;

  Future<void> idleOn<T extends SignInPhase>() async {
    for (var attempt = 0; attempt < 500; attempt++) {
      final state = viewModel().data;
      if (state.phase is T && !state.isBusy) {
        return;
      }
      await Future<void>.delayed(const Duration(milliseconds: 2));
    }
    throw TestFailure('Never idle on $T; last: ${viewModel().data.phase}');
  }

  Future<void> installed(
    PasskeyAuthenticator passkey, {
    bool isPasskeyAutoSuggestOffered = false,
  }) async {
    final harness = SignInHarness.install(
      server,
      SignInConfiguration(
        methods: const <AuthMethod>[PasswordMethod(), EmailOtpMethod()],
        isPasskeyAutoSuggestOffered: isPasskeyAutoSuggestOffered,
      ),
      passkey: passkey,
    );
    await harness.auth.initialize();
    viewModel();
  }

  test(
    'an adapter that throws leaves the UI idle and the button usable',
    () async {
      final passkey = ThrowingPasskeyAuthenticator();
      await installed(passkey);
      await idleOn<SignInChoosingMethod>();

      await viewModel().signInWithPasskey();

      expect(viewModel().data.isBusy, isFalse);
      expect(viewModel().data.feedback, SignInFeedback.unexpected);

      await viewModel().signInWithPasskey();

      expect(passkey.calls, 2, reason: 'the second tap must not be ignored');
    },
  );

  test('a failing auto-suggest does not block the manual button', () async {
    final passkey = ThrowingPasskeyAuthenticator();
    await installed(passkey, isPasskeyAutoSuggestOffered: true);
    await idleOn<SignInChoosingMethod>();
    for (var attempt = 0; attempt < 500 && passkey.calls == 0; attempt++) {
      await Future<void>.delayed(const Duration(milliseconds: 2));
    }
    await Future<void>.delayed(const Duration(milliseconds: 20));

    await viewModel().signInWithPasskey();

    expect(passkey.calls, 2);
    expect(viewModel().data.isBusy, isFalse);
  });

  test(
    'a ceremony the platform never finishes times out back to the picker',
    () async {
      final platform = FakePasskeysPlatform()..isHanging = true;
      PasskeysPlatform.instance = platform;
      await installed(
        CorbadoPasskeyAuthenticator(
          ceremonyTimeout: const Duration(milliseconds: 50),
        ),
      );
      await idleOn<SignInChoosingMethod>();

      await viewModel().signInWithPasskey();

      expect(viewModel().data.isBusy, isFalse);
      expect(viewModel().data.phase, isA<SignInChoosingMethod>());
      expect(viewModel().data.feedback, SignInFeedback.unexpected);
      expect(
        platform.authenticateRequests.single.mediation,
        corbado.MediationType.Optional,
      );
    },
    timeout: const Timeout(Duration(seconds: 5)),
  );

  testWidgets(
    'an adapter that never answers is bounded: busy resets and an error shows',
    (tester) async {
      final bound = SignInViewModel.actionTimeout;
      final passkey = HangingPasskeyAuthenticator();
      await installed(passkey);
      await tester.pump();
      expect(viewModel().data.phase, isA<SignInChoosingMethod>());

      unawaited(viewModel().signInWithPasskey());
      await tester.pump();
      expect(passkey.calls, 1);
      expect(viewModel().data.isBusy, isTrue);

      await tester.pump(bound - const Duration(seconds: 1));
      expect(viewModel().data.isBusy, isTrue, reason: 'not before the bound');

      await tester.pump(const Duration(seconds: 1));
      expect(viewModel().data.isBusy, isFalse);
      expect(viewModel().data.phase, isA<SignInChoosingMethod>());
      expect(viewModel().data.feedback, SignInFeedback.unexpected);

      unawaited(viewModel().signInWithPasskey());
      await tester.pump();
      expect(passkey.calls, 2, reason: 'the second tap must not be ignored');
      await tester.pump(bound);
    },
  );
}
