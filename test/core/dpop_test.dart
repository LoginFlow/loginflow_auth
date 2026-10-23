// TEST_CHARTER
// Requirement: RFC 9449 DPoP is mandatory for `native` + `first_party`
// clients (`doc/server-contract.md` §13, C2/C3 of the plan). The library
// must attach a valid proof to the challenge and token endpoints, and a
// client without one must be refused.
// Oracle: the fake server's own RFC 9449 §4.3 validation (signature over the
// embedded `jwk`, `htm`/`htu`, single-use `jti`) — not a mock expectation.
// `FakeLoginFlowServer.acceptedDpopThumbprints` proves the same key signed
// every proof of the flow.
// Risk edge: a request with no DPoP proof at all, once the server requires
// it — this is the exact gap `doc/server-contract.md` §13 closes.
// Layer: core, against the fake server's real validation logic (no DB/native
// platform channel involved — `TestDpopKeyStore` stands in for the
// Secure Enclave/Keystore/WebCrypto implementations, same precedent as
// `TestSigningKeys` stands in for the issuer).
// Counterfactual: a `LoginFlowAuth` configured WITHOUT `enableDpop` against
// the same DPoP-requiring server must fail with `invalid_dpop_proof`,
// proving the success case above is exercising real proof attachment, not a
// server that accepts everything.

import 'package:flutter_test/flutter_test.dart';
import 'package:loginflow_auth/loginflow_auth_core.dart';

import '../support/fake_login_flow_server.dart';
import '../support/test_dpop_key_store.dart';
import '../support/test_signing_keys.dart';

void main() {
  late TestSigningKeys keys;
  late FakeLoginFlowServer server;

  setUpAll(() => keys = TestSigningKeys.generate());

  setUp(() {
    server = FakeLoginFlowServer.inMemory(keys)..requiresDpop = true;
  });

  LoginFlowAuth authFor({required bool enableDpop}) => LoginFlowAuth(
    config: LoginFlowConfig(
      issuer: server.issuer,
      clientId: 'app-one',
      redirectUri: Uri.parse('https://app.example.com/oauth/callback'),
      enableDpop: enableDpop,
    ),
    httpClient: server.client,
    sessionStore: InMemorySessionStore(),
    pendingAuthorizationStore: InMemoryPendingAuthorizationStore(),
    dpopKeyStore: enableDpop ? TestDpopKeyStore() : null,
  );

  test('a DPoP-requiring server accepts a password sign-in with a valid proof, '
      'the same key signing both the challenge and token requests', () async {
    final auth = authFor(enableDpop: true);

    final state = await auth.signInWithPassword(
      loginHint: 'ana@example.com',
      password: 'correct-horse',
    );

    expect(state.data, isA<SignedIn>());
    expect(server.acceptedDpopThumbprints, hasLength(2));
    expect(
      server.acceptedDpopThumbprints.toSet(),
      hasLength(1),
      reason: 'the challenge and token requests must use the same key',
    );
  });

  test(
    'a client without a DPoP proof is refused by a server that requires one',
    () async {
      final auth = authFor(enableDpop: false);

      final state = await auth.signInWithPassword(
        loginHint: 'ana@example.com',
        password: 'correct-horse',
      );

      expect(
        state.errorOrNull,
        isA<OAuthProtocolError>().having(
          (error) => error.code,
          'code',
          'invalid_dpop_proof',
        ),
      );
    },
  );
}
