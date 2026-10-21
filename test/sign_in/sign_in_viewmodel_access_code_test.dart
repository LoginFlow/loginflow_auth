// Core test (tdd-light) of the access-code entry of the bundled sign-in UI.
// Requirement: with `SignInConfiguration.isAccessCodeOffered`, the UI
// redeems a typed code through `LoginFlowAuth.signInWithAccessCode` and
// turns every outcome into what the user sees: a completed sign-in, a
// field error for a malformed code (no request), a specific message for
// each refusal, a lockout countdown when throttled — and never stays busy.
// Oracle: the public `SignInState` (`phase`, `feedback`, `codeError`,
// `isBusy`) and the requests the fake server actually received, through its
// real challenge dispatch and RFC 9449 proof validation.

import 'package:flutter_test/flutter_test.dart';
import 'package:loginflow_auth/loginflow_auth.dart';
import 'package:loginflow_auth/src/sign_in/model/field_error.dart';
import 'package:loginflow_auth/src/sign_in/model/sign_in_feedback.dart';
import 'package:loginflow_auth/src/sign_in/model/sign_in_phase.dart';
import 'package:loginflow_auth/src/sign_in/service/sign_in_service.dart';
import 'package:loginflow_auth/src/sign_in/viewmodel/sign_in_viewmodel.dart';

import '../support/fake_login_flow_server.dart';
import '../support/sign_in_harness.dart';
import '../support/test_signing_keys.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late TestSigningKeys keys;
  late FakeLoginFlowServer server;

  setUpAll(() => keys = TestSigningKeys.generate());

  setUp(() {
    server = FakeLoginFlowServer.inMemory(keys)..requiresDpop = true;
  });

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

  Future<void> installed({
    List<AuthMethod> methods = const <AuthMethod>[],
    bool enableDpop = true,
  }) async {
    final harness = SignInHarness.install(
      server,
      SignInConfiguration(methods: methods, isAccessCodeOffered: true),
      enableDpop: enableDpop,
    );
    await harness.auth.initialize();
    viewModel();
  }

  test('with no other method the access-code step is the entry screen, and a '
      'typed code signs the subject in', () async {
    await installed();
    await idleOn<SignInAccessCodeEntry>();

    await viewModel().submitAccessCode('k7m2-q9px');

    final phase = viewModel().data.phase;
    expect(phase, isA<SignInCompleted>());
    final identity = (phase as SignInCompleted).session.identity;
    expect(identity.externalSubject, 'driver:7');
    expect(identity.subjectKind, AccessSubjectKind.person);
    expect(server.challengeRequests.single['access_code'], 'K7M2Q9PX');
    expect(viewModel().data.isBusy, isFalse);
  });

  test('an incomplete code is refused locally, with no request', () async {
    await installed();
    await idleOn<SignInAccessCodeEntry>();

    await viewModel().submitAccessCode('K7M2-Q9');

    expect(viewModel().data.codeError, FieldError.incompleteAccessCode);
    expect(server.challengeRequests, isEmpty);
  });

  test(
    'every refusal shows its own message and leaves the step usable',
    () async {
      await installed();
      await idleOn<SignInAccessCodeEntry>();

      await viewModel().submitAccessCode('ZZZZ-ZZZZ');

      expect(viewModel().data.feedback, SignInFeedback.invalidAccessCode);
      expect(viewModel().data.phase, isA<SignInAccessCodeEntry>());
      expect(viewModel().data.isBusy, isFalse);

      server.areAccessCodesEnabled = false;
      await viewModel().submitAccessCode(FakeLoginFlowServer.accessCode);

      expect(viewModel().data.feedback, SignInFeedback.accessCodesUnavailable);
      expect(viewModel().data.isBusy, isFalse);
    },
  );

  test('a throttled redemption counts down the server Retry-After', () async {
    await installed();
    await idleOn<SignInAccessCodeEntry>();
    server.isAccessCodeThrottled = true;

    await viewModel().submitAccessCode(FakeLoginFlowServer.accessCode);

    expect(viewModel().data.phase, const SignInLockedOut(secondsLeft: 900));
    expect(viewModel().data.isBusy, isFalse);
  });

  test('a client without DPoP is told the app is not set up for codes, '
      'before any request', () async {
    await installed(enableDpop: false);
    await idleOn<SignInAccessCodeEntry>();

    await viewModel().submitAccessCode(FakeLoginFlowServer.accessCode);

    expect(viewModel().data.feedback, SignInFeedback.accessCodeNotConfigured);
    expect(server.challengeRequests, isEmpty);
    expect(viewModel().data.isBusy, isFalse);
  });

  test('next to other methods it is an opt-in entry with a way back', () async {
    await installed(
      methods: const <AuthMethod>[PasswordMethod(), EmailOtpMethod()],
    );
    await idleOn<SignInChoosingMethod>();
    expect(viewModel().data.isAccessCodeOffered, isTrue);

    viewModel().useAccessCode();

    expect(viewModel().data.phase, isA<SignInAccessCodeEntry>());
    expect(viewModel().data.canGoBack, isTrue);

    await viewModel().goBack();

    expect(viewModel().data.phase, isA<SignInChoosingMethod>());
  });
}
