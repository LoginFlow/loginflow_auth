// Core test (tdd-light) of the bundled passkey manager.
// Requirement: for a signed-in user, `PasskeysViewModel` lists, adds,
// renames and deletes passkeys through `LoginFlowAuth`; a `StepUpRequired`
// on enrollment is handled exactly as `enrollPasskey` documents it —
// `stepUp(requirement)`, the user signs in again, then ONE retry — and a
// failed ceremony shows its real `PasskeyFailed` reason.
// Oracle: the public `PasskeysState` and what the fake server holds after
// each call (its real `/v1/user/passkeys*` dispatch, the recent-auth gate
// of `recent_auth.rs` and the challenge it opens for the step-up).

import 'package:flutter_test/flutter_test.dart';
import 'package:loginflow_auth/loginflow_auth.dart';
import 'package:loginflow_auth/src/sign_in/model/passkeys_feedback.dart';
import 'package:loginflow_auth/src/sign_in/model/passkeys_phase.dart';
import 'package:loginflow_auth/src/sign_in/model/sign_in_phase.dart';
import 'package:loginflow_auth/src/sign_in/service/passkeys_service.dart';
import 'package:loginflow_auth/src/sign_in/service/sign_in_service.dart';
import 'package:loginflow_auth/src/sign_in/viewmodel/passkeys_viewmodel.dart';

import '../support/fake_login_flow_server.dart';
import '../support/fake_passkey_authenticator.dart';
import '../support/sign_in_harness.dart';
import '../support/test_signing_keys.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late TestSigningKeys keys;
  late FakeLoginFlowServer server;
  late FakePasskeyAuthenticator passkey;
  late SignInHarness harness;

  setUpAll(() => keys = TestSigningKeys.generate());

  setUp(() async {
    server = FakeLoginFlowServer.inMemory(keys);
    passkey = FakePasskeyAuthenticator(credentialId: 'credential-new-0001');
    harness = SignInHarness.install(
      server,
      const SignInConfiguration(methods: <AuthMethod>[PasswordMethod()]),
      passkey: passkey,
    );
    await harness.auth.initialize();
    final signedIn = await harness.auth.signInWithPassword(
      loginHint: 'ana@example.com',
      password: 'correct-horse',
    );
    expect(signedIn.data, isA<SignedIn>());
  });

  PasskeysViewModel manager() => PasskeysService.manager.notifier;

  Future<T> idleOn<T extends PasskeysPhase>() async {
    for (var attempt = 0; attempt < 500; attempt++) {
      final state = manager().data;
      if (state.phase case final T phase when !state.isBusy) {
        return phase;
      }
      await Future<void>.delayed(const Duration(milliseconds: 2));
    }
    throw TestFailure('Never idle on $T; last: ${manager().data.phase}');
  }

  Future<List<PasskeyCredential>> serverPasskeys() async =>
      (await harness.auth.listPasskeys()).data;

  test('adds, renames and deletes the signed-in user\'s passkeys', () async {
    expect((await idleOn<PasskeysListed>()).passkeys, isEmpty);

    await manager().addPasskey();

    final added = (await idleOn<PasskeysListed>()).passkeys;
    expect(added.map((passkey) => passkey.id), <String>['credential-new-0001']);
    expect(await serverPasskeys(), added);

    await manager().renamePasskey(id: 'credential-new-0001', name: ' Laptop ');

    final renamed = (await idleOn<PasskeysListed>()).passkeys.single;
    expect(renamed.name, 'Laptop');
    expect((await serverPasskeys()).single.name, 'Laptop');

    await manager().deletePasskey('credential-new-0001');

    expect((await idleOn<PasskeysListed>()).passkeys, isEmpty);
    expect(await serverPasskeys(), isEmpty);
  });

  test('a stale sign-in steps up with the server requirement, the user '
      'signs in again, and the enrollment is retried once', () async {
    await idleOn<PasskeysListed>();
    server.expireRecentAuthentications();

    await manager().addPasskey();

    await idleOn<PasskeysReauthenticating>();
    expect(server.challengeRequests.last['max_age'], '300');
    expect(await serverPasskeys(), isEmpty);

    final signIn = SignInService.flow.notifier;
    for (var attempt = 0; attempt < 500; attempt++) {
      if (signIn.data.phase is SignInPasswordEntry && !signIn.data.isBusy) {
        break;
      }
      await Future<void>.delayed(const Duration(milliseconds: 2));
    }
    await signIn.submitPassword(email: '', password: 'correct-horse');

    final listed = (await idleOn<PasskeysListed>()).passkeys;
    expect(listed.map((passkey) => passkey.id), <String>[
      'credential-new-0001',
    ]);
    expect(manager().data.feedback, PasskeysFeedback.none);
    expect(await serverPasskeys(), listed);
  });

  test('cancelling the re-authentication goes back to the list, with no '
      'retry', () async {
    await idleOn<PasskeysListed>();
    server.expireRecentAuthentications();
    await manager().addPasskey();
    await idleOn<PasskeysReauthenticating>();

    await manager().cancelReauthentication();

    expect((await idleOn<PasskeysListed>()).passkeys, isEmpty);
    expect(manager().data.feedback, PasskeysFeedback.none);
    expect(harness.auth.state, isA<SignedIn>());
  });

  test('a failed ceremony shows its real reason and the manager stays '
      'usable', () async {
    await idleOn<PasskeysListed>();
    passkey.enrollmentFailure = PasskeyFailureReason.alreadyRegistered;

    await manager().addPasskey();

    await idleOn<PasskeysListed>();
    expect(manager().data.feedback, PasskeysFeedback.passkeyAlreadyRegistered);

    passkey.enrollmentFailure = PasskeyFailureReason.domainNotAssociated;
    await manager().addPasskey();

    expect(
      manager().data.feedback,
      PasskeysFeedback.passkeyDomainNotAssociated,
    );
    expect(manager().data.isBusy, isFalse);
  });
}
