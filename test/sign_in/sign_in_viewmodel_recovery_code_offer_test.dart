// Core test (tdd-light) of the TOTP step's "Use a recovery code" offer.
// Requirement: the bundled TOTP step offers a recovery code exactly when the
// server's 403 lists `recovery_code` in `methods`, which the real server does
// only while the account holds an unused code
// (`loginflow_api/src/features/login_engine/service/challenge_service.rs:1676-1686`).
// Oracle: the public `SignInState` of the prebuilt `SignInViewModel`, and
// whether a recovery code then signs the user in.

import 'package:flutter_test/flutter_test.dart';
import 'package:loginflow_auth/loginflow_auth.dart';
import 'package:loginflow_auth/src/sign_in/model/sign_in_phase.dart';
import 'package:loginflow_auth/src/sign_in/service/sign_in_service.dart';
import 'package:loginflow_auth/src/sign_in/viewmodel/sign_in_viewmodel.dart';

import '../support/fake_login_flow_server.dart';
import '../support/sign_in_harness.dart';
import '../support/test_signing_keys.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const email = 'tomas@example.com';
  const password = 'battery-staple';

  late TestSigningKeys keys;
  late FakeLoginFlowServer server;
  late SignInHarness harness;

  setUpAll(() => keys = TestSigningKeys.generate());

  setUp(() => server = FakeLoginFlowServer.inMemory(keys));

  SignInViewModel signIn() => SignInService.flow.notifier;

  Future<T> idleOn<T extends SignInPhase>() async {
    for (var attempt = 0; attempt < 500; attempt++) {
      final state = signIn().data;
      if (state.phase case final T phase when !state.isBusy) {
        return phase;
      }
      await Future<void>.delayed(const Duration(milliseconds: 2));
    }
    throw TestFailure('Never idle on $T; last: ${signIn().data.phase}');
  }

  /// Signs [email] in with its password through the bundled password step;
  /// the server then asks for the TOTP, whose step is returned.
  Future<SignInTotpEntry> totpStepAfterPassword() async {
    harness = SignInHarness.install(
      server,
      const SignInConfiguration(methods: <AuthMethod>[PasswordMethod()]),
    );
    await harness.auth.initialize();
    await idleOn<SignInPasswordEntry>();

    await signIn().submitPassword(email: email, password: password);

    return idleOn<SignInTotpEntry>();
  }

  test('the TOTP step offers a recovery code while the account has one, '
      'and that code signs the user in', () async {
    final totpStep = await totpStepAfterPassword();

    expect(totpStep.isRecoveryCode, isFalse);
    expect(totpStep.canUseRecoveryCode, isTrue);

    signIn().toggleRecoveryCode();
    expect((await idleOn<SignInTotpEntry>()).isRecoveryCode, isTrue);

    await signIn().submitSecondFactor(FakeLoginFlowServer.recoveryCode);

    final completed = await idleOn<SignInCompleted>();
    expect(completed.session.identity.subject, 'cu_tomas');
  });

  test('no recovery code is offered when the account has none left', () async {
    server.users[email] = const FakeUser(
      subject: 'cu_tomas',
      email: email,
      password: password,
      isTotpEnabled: true,
      hasUnusedRecoveryCodes: false,
    );

    final totpStep = await totpStepAfterPassword();

    expect(totpStep.canUseRecoveryCode, isFalse);
    signIn().toggleRecoveryCode();
    expect(signIn().data.phase, totpStep);
  });
}
