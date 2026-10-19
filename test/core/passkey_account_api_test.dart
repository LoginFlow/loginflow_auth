// TEST_CHARTER
// Requirement: every `/v1/user/passkeys*` call (`enrollPasskey`,
// `listPasskeys`, `renamePasskey`, `deletePasskey`) must unwrap the
// server's standard envelope (`{"data": <payload>, "meta": {...}}`,
// `doc/server-contract.md` §15 / `response_entity.rs`), never treat the
// envelope itself as the payload.
// Oracle: the parsed `PasskeyCredential`s carry the real field values the
// fake server stored (id, name, timestamps) and `listPasskeys` returns the
// actual array, not a parse error — observable end to end through
// `LoginFlowAuth`, the same object the admin panel calls.
// Risk edge: `listPasskeys()` is the sharpest case — the historic bug
// decoded the raw body and rejected the envelope object as "not a JSON
// array", so the admin panel never saw the user's passkeys at all.
// Layer: core, against the fake server's real HTTP dispatch (no mocked
// transport) — this is exactly the wire shape bug, a mock of
// `PasskeyAccountClient` would not have caught it.
// Counterfactual: parsing the envelope object/array directly as the
// payload (the pre-fix code) makes this fail on `listPasskeys` with
// `ServerResponseInvalid` ("not a JSON array") and on the other three with
// a `FormatException`-turned-`ServerResponseInvalid` (missing `id`) —
// confirmed by running this test against the unfixed client.

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

  test('enroll, list, rename and delete a passkey through the envelope-wrapped '
      'account API', () async {
    final fixture = AuthFixture.create(
      server,
      passkey: FakePasskeyAuthenticator(credentialId: 'credential-new-0001'),
    );
    await fixture.auth.initialize();
    final signedIn = await fixture.auth.signInWithPassword(
      loginHint: 'ana@example.com',
      password: 'correct-horse',
    );
    expect(signedIn.data, isA<SignedIn>());

    final enrolled = await fixture.auth.enrollPasskey(
      username: 'ana@example.com',
      displayName: 'Ana Ruiz',
    );
    expect(enrolled, isA<Ok<PasskeyCredential, LoginFlowError>>());
    final credential = (enrolled as Ok<PasskeyCredential, LoginFlowError>).data;
    expect(credential.id, 'credential-new-0001');
    expect(credential.name, isNull);

    final listed = await fixture.auth.listPasskeys();
    expect(listed, isA<Ok<List<PasskeyCredential>, LoginFlowError>>());
    expect(
      (listed as Ok<List<PasskeyCredential>, LoginFlowError>).data,
      <PasskeyCredential>[credential],
    );

    final renamed = await fixture.auth.renamePasskey(
      id: credential.id,
      name: 'Work laptop',
    );
    expect(renamed, isA<Ok<PasskeyCredential, LoginFlowError>>());
    expect(
      (renamed as Ok<PasskeyCredential, LoginFlowError>).data.name,
      'Work laptop',
    );

    final deleted = await fixture.auth.deletePasskey(credential.id);
    expect(deleted, isA<Ok<void, LoginFlowError>>());

    final listedAfterDelete = await fixture.auth.listPasskeys();
    expect(
      (listedAfterDelete as Ok<List<PasskeyCredential>, LoginFlowError>).data,
      isEmpty,
    );
  });
}
