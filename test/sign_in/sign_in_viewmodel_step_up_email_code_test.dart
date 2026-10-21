// Core test (tdd-light) of the re-authentication's email-code way in.
// Requirement: when LoginFlow asks a signed-in user to re-authenticate (the
// step-up before adding a passkey), the bundled password step offers
// "Email me a code" whenever the client allows `email_otp` — the server's
// login options list it, or the prompt's alternatives do — and the user
// completes the step-up with the emailed code (resend included). An account
// with an unknown password (created through a tenant's service door) is
// otherwise stuck on a password it never had.
// Oracle: the public `SignInState`, the codes the fake server emailed and
// the passkeys it holds afterwards. The fake mirrors the real server for a
// step-up: `next: password` with NO `methods`
// (`loginflow_api/src/features/login_engine/model/challenge_wire_model.rs:125-131`),
// while still taking `method=email_otp` on that `auth_session`.

import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:loginflow_auth/loginflow_auth.dart';
import 'package:loginflow_auth/src/sign_in/model/passkeys_phase.dart';
import 'package:loginflow_auth/src/sign_in/model/sign_in_phase.dart';
import 'package:loginflow_auth/src/sign_in/service/passkeys_service.dart';
import 'package:loginflow_auth/src/sign_in/service/sign_in_service.dart';
import 'package:loginflow_auth/src/sign_in/viewmodel/passkeys_viewmodel.dart';
import 'package:loginflow_auth/src/sign_in/viewmodel/sign_in_viewmodel.dart';

import '../support/fake_login_flow_server.dart';
import '../support/fake_passkey_authenticator.dart';
import '../support/sign_in_harness.dart';
import '../support/test_signing_keys.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const email = 'carla@example.com';

  late TestSigningKeys keys;
  late FakeLoginFlowServer server;
  late SignInHarness harness;

  setUpAll(() => keys = TestSigningKeys.generate());

  setUp(() {
    server = FakeLoginFlowServer.inMemory(keys);
    // A service-door account: a random password nobody knows.
    server.users[email] = FakeUser(
      subject: 'cu_carla',
      email: email,
      password: 'unknown-${Random.secure().nextInt(1 << 32)}',
      name: 'Carla Diaz',
    );
  });

  SignInViewModel signIn() => SignInService.flow.notifier;

  PasskeysViewModel manager() => PasskeysService.manager.notifier;

  Future<T> signInIdleOn<T extends SignInPhase>() async {
    for (var attempt = 0; attempt < 500; attempt++) {
      final state = signIn().data;
      if (state.phase case final T phase when !state.isBusy) {
        return phase;
      }
      await Future<void>.delayed(const Duration(milliseconds: 2));
    }
    throw TestFailure('Never idle on $T; last: ${signIn().data.phase}');
  }

  Future<T> managerIdleOn<T extends PasskeysPhase>() async {
    for (var attempt = 0; attempt < 500; attempt++) {
      final state = manager().data;
      if (state.phase case final T phase when !state.isBusy) {
        return phase;
      }
      await Future<void>.delayed(const Duration(milliseconds: 2));
    }
    throw TestFailure('Never idle on $T; last: ${manager().data.phase}');
  }

  /// Signs [email] in with an emailed code, lets the recent-auth window
  /// pass and asks to add a passkey: the server answers with a step-up,
  /// whose password step is returned.
  Future<SignInPasswordEntry> stepUpOnPasskeyEnrollment() async {
    harness = SignInHarness.install(
      server,
      const SignInConfiguration(
        methods: <AuthMethod>[
          PasswordMethod(),
          EmailOtpMethod(resendCooldown: Duration.zero),
        ],
      ),
      passkey: FakePasskeyAuthenticator(credentialId: 'credential-new-0001'),
    );
    await harness.auth.initialize();
    await harness.auth.requestEmailOtp(loginHint: email);
    final signedIn = await harness.auth.submitEmailOtp(
      FakeLoginFlowServer.emailOtpCode,
    );
    expect(signedIn.data, isA<SignedIn>());
    await managerIdleOn<PasskeysListed>();
    server.expireRecentAuthentications();

    await manager().addPasskey();

    await managerIdleOn<PasskeysReauthenticating>();
    expect(server.challengeRequests.last['max_age'], '300');
    return signInIdleOn<SignInPasswordEntry>();
  }

  test('a step-up opened with only `next: password` is completed with an '
      'emailed code, and the passkey is then added', () async {
    final passwordStep = await stepUpOnPasskeyEnrollment();

    expect(passwordStep.isIdentifierLocked, isTrue);
    expect(passwordStep.isEmailCodeOffered, isTrue);
    server.sentEmailOtps.clear();

    await signIn().useEmailCode();

    final otpStep = await signInIdleOn<SignInOtpEntry>();
    expect(otpStep.email, email);
    expect(server.sentEmailOtps, <String>[email]);

    await signIn().resendEmailCode();

    expect(server.sentEmailOtps, <String>[email, email]);

    await signIn().submitEmailCode(FakeLoginFlowServer.emailOtpCode);

    final listed = (await managerIdleOn<PasskeysListed>()).passkeys;
    expect(listed.map((passkey) => passkey.id), <String>[
      'credential-new-0001',
    ]);
    expect((await harness.auth.listPasskeys()).data, listed);
  });

  test('no email code is offered when neither the login options nor the '
      "prompt's alternatives allow it", () async {
    server.loginMethods = <String>['password'];

    final passwordStep = await stepUpOnPasskeyEnrollment();

    expect(passwordStep.isEmailCodeOffered, isFalse);
    server.sentEmailOtps.clear();
    await signIn().useEmailCode();
    expect(server.sentEmailOtps, isEmpty);
    expect(signIn().data.phase, passwordStep);
  });

  test(
    "the prompt's alternatives are honored when they list email_otp",
    () async {
      server
        ..loginMethods = <String>['password']
        ..passwordStepMethods = <String>['password', 'email_otp'];

      final passwordStep = await stepUpOnPasskeyEnrollment();

      expect(passwordStep.isEmailCodeOffered, isTrue);
    },
  );
}
