// TEST_CHARTER
// Requirement: when `POST /v1/user/passkeys/enroll/start` refuses the access
// token because the sign-in is too old (RFC 9470: `401` +
// `WWW-Authenticate: Bearer error="insufficient_user_authentication",
// max_age=300`, `recent_auth.rs`), `enrollPasskey` must surface a typed
// `StepUpRequired` carrying that `StepUpRequirement`, so an app can call
// `LoginFlowAuth.stepUp(requirement)` and retry — not an opaque
// `ServerResponseInvalid(401)` indistinguishable from any other refusal.
// Oracle: the `Result` of the public `enrollPasskey`, against the fake
// server's real HTTP dispatch answering exactly like the real gate (status,
// error envelope and challenge header).
// Risk edge: the challenge lives only in the header — the body is the
// generic `UNAUTHORIZED` envelope every 401 shares — so the mapping must
// read the header, not the body.
// Layer: core, through `LoginFlowAuth` and the real transport (the header
// is read at the HTTP boundary; a mocked `PasskeyAccountClient` would skip
// exactly that).
// Counterfactual: the same call with a fresh sign-in (gate open) enrolls
// normally, so the step-up error is caused by the gate, not by the call.

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
    server = await FakeLoginFlowServer.start(keys);
  });

  tearDown(() => server.close());

  Future<AuthFixture> signedIn() async {
    final fixture = AuthFixture.create(
      server,
      passkey: FakePasskeyAuthenticator(credentialId: 'credential-new-0001'),
    );
    await fixture.auth.initialize();
    final result = await fixture.auth.signInWithPassword(
      loginHint: 'ana@example.com',
      password: 'correct-horse',
    );
    expect(result.data, isA<SignedIn>());
    return fixture;
  }

  test('a stale sign-in on enroll/start -> StepUpRequired with the '
      "server's max_age", () async {
    final fixture = await signedIn();
    server.expireRecentAuthentications();

    final enrolled = await fixture.auth.enrollPasskey(
      username: 'ana@example.com',
      displayName: 'Ana Ruiz',
    );

    expect(
      enrolled.errorOrNull,
      const StepUpRequired(
        requirement: StepUpRequirement(maxAge: Duration(seconds: 300)),
      ),
    );
  });

  test('with the gate open the same call enrolls', () async {
    final fixture = await signedIn();

    final enrolled = await fixture.auth.enrollPasskey(
      username: 'ana@example.com',
      displayName: 'Ana Ruiz',
    );

    expect(enrolled.data.id, 'credential-new-0001');
  });
}
