// Core test (tdd-light) of the bundled passkey manager for a passkey-only
// account (API 0.26.0): it has no email, so its next passkey is named in the
// platform's passkey sheet by its name, never by its opaque `sub`.
// Oracle: the creation options the platform's sheet received from the fake
// server's real `/v1/user/passkeys/enroll/start` (DPoP required).

import 'package:flutter_test/flutter_test.dart';
import 'package:loginflow_auth/loginflow_auth.dart';
import 'package:loginflow_auth/src/sign_in/model/passkeys_phase.dart';
import 'package:loginflow_auth/src/sign_in/service/passkeys_service.dart';
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
    server = FakeLoginFlowServer.inMemory(keys)
      ..requiresDpop = true
      ..loginMethods = <String>['passkey', 'passkey_signup'];
    passkey = FakePasskeyAuthenticator();
    harness = SignInHarness.install(
      server,
      const SignInConfiguration(methods: <AuthMethod>[]),
      passkey: passkey,
      enableDpop: true,
    );
    await harness.auth.initialize();
  });

  PasskeysViewModel manager() => PasskeysService.manager.notifier;

  Future<void> idleOnList() async {
    for (var attempt = 0; attempt < 500; attempt++) {
      final state = manager().data;
      if (state.phase is PasskeysListed && !state.isBusy) {
        return;
      }
      await Future<void>.delayed(const Duration(milliseconds: 2));
    }
    throw TestFailure('Never idle on the list; last: ${manager().data.phase}');
  }

  test('the sheet names a second passkey by the account name', () async {
    final signedUp = await harness.auth.signUpWithPasskey(displayName: 'Ana');
    expect(signedUp.data, isA<SignedIn>());
    await idleOnList();

    await manager().addPasskey();

    await idleOnList();
    final sheet = passkey.creationOptionsSeen.last['user']!;
    expect(sheet, containsPair('name', 'Ana'));
    expect(sheet, containsPair('displayName', 'Ana'));
  });
}
