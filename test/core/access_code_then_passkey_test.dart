// TEST_CHARTER
// Requirement: "code once, then passkey" (`doc/integration-guide.md`). An
// app redeems an access code, enrolls a passkey on that subject session,
// and once the session has ended signs in with `signInWithPasskey()` — no
// arguments — on a client that lists only `access_code` and `passkey`; the
// new session is the same subject (`ext_sub`, `subject_kind`,
// `ext_profile`), DPoP-bound. A passkey account call the server cannot
// serve answers a coded `403`, reported as `PasskeyAccountRefused` with
// that code, never a generic failure (`doc/server-contract.md` §15).
// Oracle: the public `SignedIn` identity, the stored session's `dpopJkt`,
// the challenge request the fake server received, and the typed error of
// the account API — through the fake server's real dispatch and RFC 9449
// proof validation.
// Risk edge: the second sign-in carries no `login_hint`, so only the
// credential id identifies the subject; the refusal is the server's
// envelope `403`, which used to come back as `ServerResponseInvalid`.
// Layer: core over a real loopback HTTP server (`FakeLoginFlowServer.start`)
// — the wire format is the risk, so no transport is mocked.
// A passkey the server no longer accepts ends the sign-in with
// `PasskeyRejected`, without running the ceremony again.
// Counterfactual: mapping the `403` like any other failed account call
// (the pre-change `toAccountApiError`) fails the refusal case with
// `ServerResponseInvalid(statusCode: 403)`; answering a rejected assertion
// like a fresh step (the pre-change `_answerWebauthnAssertion`) fails the
// deleted-passkey case with `ServerResponseInvalid` ("without options").

import 'package:flutter_test/flutter_test.dart';
import 'package:loginflow_auth/loginflow_auth_core.dart';

import '../support/auth_fixture.dart';
import '../support/fake_login_flow_server.dart';
import '../support/fake_passkey_authenticator.dart';
import '../support/test_signing_keys.dart';

void main() {
  late TestSigningKeys keys;
  late FakeLoginFlowServer server;

  setUpAll(() => keys = TestSigningKeys.generate());

  setUp(() async {
    server = await FakeLoginFlowServer.start(keys)
      ..requiresDpop = true
      ..loginMethods = <String>['access_code', 'passkey'];
  });

  tearDown(() => server.close());

  Future<AuthFixture> signedInWithCode({
    FakePasskeyAuthenticator? passkey,
  }) async {
    final fixture = AuthFixture.create(
      server,
      enableDpop: true,
      passkey:
          passkey ??
          FakePasskeyAuthenticator(credentialId: 'credential-subject-0001'),
    );
    await fixture.auth.initialize();
    final redeemed = await fixture.auth.signInWithAccessCode(
      FakeLoginFlowServer.accessCode,
    );
    expect(redeemed.data, isA<SignedIn>());
    return fixture;
  }

  test('after a code, a passkey signs the same subject in again with no '
      'code and no login hint', () async {
    final fixture = await signedInWithCode();
    final enrolled = await fixture.auth.enrollPasskey(
      username: 'driver:7',
      displayName: 'driver:7',
    );
    expect(enrolled.data.id, 'credential-subject-0001');
    await fixture.auth.signOut(SignOutScope.app);
    expect(fixture.auth.state, isA<SignedOut>());

    final result = await fixture.auth.signInWithPasskey();

    final state = result.data;
    expect(state, isA<SignedIn>());
    final identity = (state as SignedIn).session.identity;
    expect(identity.subject, 'as_driver_7');
    expect(identity.externalSubject, 'driver:7');
    expect(identity.subjectKind, AccessSubjectKind.person);
    expect(identity.subjectProfile, 'Driver');
    expect(identity.email, isNull);
    final identify = server.challengeRequests.firstWhere(
      (request) => request['method'] == 'webauthn_identify',
    );
    expect(identify.containsKey('login_hint'), isFalse);
    expect((await fixture.storedSession())?.dpopJkt, isNotNull);
  });

  test('a coded 403 from the passkey account API is PasskeyAccountRefused '
      'with the server code', () async {
    final fixture = await signedInWithCode();
    server.passkeyAccountRefusal = 'passkey_owner_unsupported';

    final enrolled = await fixture.auth.enrollPasskey(
      username: 'driver:7',
      displayName: 'driver:7',
    );
    final listed = await fixture.auth.listPasskeys();

    const refused = PasskeyAccountRefused(code: 'passkey_owner_unsupported');
    expect(enrolled, isA<Err<PasskeyCredential, LoginFlowError>>());
    expect(enrolled.errorOrNull, refused);
    expect(listed.errorOrNull, refused);
  });

  test('a passkey the server deleted (a new code, a revocation) ends the '
      'sign-in with PasskeyRejected, without a second ceremony', () async {
    final passkey = FakePasskeyAuthenticator(
      credentialId: 'credential-subject-0001',
    );
    final fixture = await signedInWithCode(passkey: passkey);
    await fixture.auth.enrollPasskey(
      username: 'driver:7',
      displayName: 'driver:7',
    );
    await fixture.auth.signOut(SignOutScope.app);
    server.deletePasskeysOf('as_driver_7');

    final result = await fixture.auth.signInWithPasskey();

    expect(result.errorOrNull, const PasskeyRejected());
    expect(passkey.assertionOptionsSeen, hasLength(1));
    expect(fixture.auth.state, isA<SignedOut>());
  });
}
