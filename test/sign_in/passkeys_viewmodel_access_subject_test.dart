// Core test (tdd-light) of the bundled passkey manager for an access-code
// subject.
// Requirement: a subject signed in with an access code — a `person` or a
// `device` — is offered "Add a passkey" and enrolls one, so its next
// sign-in needs no code; the platform's passkey sheet shows the subject's
// display name, else its external id (`doc/server-contract.md` §15).
// Oracle: the public `PasskeysState`, the passkeys the fake server holds
// after the enrollment (its real `/v1/user/passkeys*` dispatch, DPoP
// required) and the creation options the platform's sheet received.

import 'package:flutter_test/flutter_test.dart';
import 'package:loginflow_auth/loginflow_auth.dart';
import 'package:loginflow_auth/src/sign_in/model/passkeys_feedback.dart';
import 'package:loginflow_auth/src/sign_in/model/passkeys_phase.dart';
import 'package:loginflow_auth/src/sign_in/service/passkeys_service.dart';
import 'package:loginflow_auth/src/sign_in/viewmodel/passkeys_viewmodel.dart';

import '../support/fake_login_flow_server.dart';
import '../support/fake_passkey_authenticator.dart';
import '../support/sign_in_harness.dart';
import '../support/test_signing_keys.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const code = 'DEVC2345';

  late TestSigningKeys keys;
  late FakeLoginFlowServer server;
  late FakePasskeyAuthenticator passkey;
  late SignInHarness harness;

  setUpAll(() => keys = TestSigningKeys.generate());

  setUp(() async {
    server = FakeLoginFlowServer.inMemory(keys)
      ..requiresDpop = true
      ..loginMethods = <String>['access_code', 'passkey'];
    passkey = FakePasskeyAuthenticator(credentialId: 'credential-subject-0001');
    harness = SignInHarness.install(
      server,
      const SignInConfiguration(
        methods: <AuthMethod>[],
        isAccessCodeOffered: true,
      ),
      passkey: passkey,
      enableDpop: true,
    );
    await harness.auth.initialize();
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

  Future<void> redeemCodeOf(FakeUser subject) async {
    server.accessCodes[code] = subject;
    final signedIn = await harness.auth.signInWithAccessCode(code);
    expect(signedIn.data, isA<SignedIn>());
  }

  Map<String, Object?> sheetAccount() =>
      passkey.creationOptionsSeen.single['user']! as Map<String, Object?>;

  test('a device subject enrolls a passkey', () async {
    await redeemCodeOf(
      const FakeUser(
        subject: 'as_recorder_1',
        externalSubject: 'recorder:1',
        subjectKind: 'device',
        subjectProfile: 'Recorder',
      ),
    );
    expect((await idleOn<PasskeysListed>()).passkeys, isEmpty);

    await manager().addPasskey();

    final listed = (await idleOn<PasskeysListed>()).passkeys;
    expect(listed.map((passkey) => passkey.id), <String>[
      'credential-subject-0001',
    ]);
    expect(manager().data.feedback, PasskeysFeedback.none);
    expect((await harness.auth.listPasskeys()).data, listed);
  });

  test('the sheet shows the subject display name', () async {
    await redeemCodeOf(
      const FakeUser(
        subject: 'as_driver_8',
        externalSubject: 'driver:8',
        subjectKind: 'person',
        subjectProfile: 'Driver',
        name: 'Marta Rios',
      ),
    );
    await idleOn<PasskeysListed>();

    await manager().addPasskey();

    await idleOn<PasskeysListed>();
    expect(sheetAccount()['name'], 'Marta Rios');
    expect(sheetAccount()['displayName'], 'Marta Rios');
  });

  test('without a display name the sheet shows the external id', () async {
    await redeemCodeOf(
      const FakeUser(
        subject: 'as_driver_9',
        externalSubject: 'driver:9',
        subjectKind: 'person',
        subjectProfile: 'Driver',
      ),
    );
    await idleOn<PasskeysListed>();

    await manager().addPasskey();

    await idleOn<PasskeysListed>();
    expect(sheetAccount()['name'], 'driver:9');
    expect(sheetAccount()['displayName'], 'driver:9');
  });
}
