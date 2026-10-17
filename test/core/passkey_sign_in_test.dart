// TEST_CHARTER
// Requirement: a passkey sign-in (`method=webauthn_identify` ->
// `webauthn_assertion`) must run end to end and produce a validated,
// stored session — the WebAuthn L3 ceremony (`doc/server-contract.md`
// passkeys section), with DPoP (RFC 9449)
// still attached to every leg for a native+first_party client.
// Oracle: the fake server's own dispatch (`method=webauthn_identify` ->
// `next: webauthn_assertion` with `options`; a valid `webauthn_assertion`
// issues a code) plus the real DPoP proof validation already exercised by
// `dpop_test.dart` — not a mock expectation.
// Risk edge: the server rejecting a credential id it does not recognize
// (`step_error: invalid_credential`) must keep the attempt alive rather
// than silently signing in.
// Layer: core, against the fake server's real HTTP dispatch (no native
// platform channel — `FakePasskeyAuthenticator` stands in for
// Credential Manager/AuthenticationServices, same precedent as
// `FakeGoogleSource` for Credential Manager/GIDSignIn).
// Counterfactual: a `FakePasskeyAuthenticator` configured with the WRONG
// credential id must fail with `invalid_credential` and no tokens issued —
// proving the success case exercises the real assertion check, not a
// server that accepts everything.

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

  group('Passkey sign-in (WebAuthn L3)', () {
    test(
      'identify -> assertion -> code -> tokens, with a DPoP proof on every '
      'leg',
      () async {
        server.requiresDpop = true;
        final passkey = FakePasskeyAuthenticator();
        final fixture = AuthFixture.create(
          server,
          passkey: passkey,
          enableDpop: true,
        );
        await fixture.auth.initialize();

        final result = await fixture.auth.signInWithPasskey(
          loginHint: 'ana@example.com',
        );

        final state = result.data;
        expect(state, isA<SignedIn>());
        final identity = (state as SignedIn).session.identity;
        expect(identity.subject, 'cu_ana');

        expect(passkey.assertionOptionsSeen, hasLength(1));
        expect(passkey.assertionOptionsSeen.single, contains('challenge'));

        final tokenRequest = server.tokenRequests.single;
        expect(tokenRequest['grant_type'], 'authorization_code');

        expect(
          server.acceptedDpopThumbprints.toSet(),
          hasLength(1),
          reason:
              'the challenge (identify + assertion) and token requests '
              'must use the same DPoP key',
        );
        expect(server.acceptedDpopThumbprints, hasLength(3));
      },
    );

    test(
      'an unrecognized credential fails the attempt without issuing a code '
      '(a WebAuthn challenge is single-use: the caller restarts with a new '
      'signInWithPasskey call, there is nothing to retry blindly)',
      () async {
        final passkey = FakePasskeyAuthenticator(credentialId: 'not-enrolled');
        final fixture = AuthFixture.create(server, passkey: passkey);
        await fixture.auth.initialize();

        final result = await fixture.auth.signInWithPasskey(
          loginHint: 'ana@example.com',
        );

        expect(
          result.errorOrNull,
          isA<ServerResponseInvalid>().having(
            (error) => error.statusCode,
            'statusCode',
            403,
          ),
        );
        expect(server.tokenRequests, isEmpty);
      },
    );

    test('the user cancelling the platform sheet ends the attempt', () async {
      final passkey = FakePasskeyAuthenticator()..shouldCancel = true;
      final fixture = AuthFixture.create(server, passkey: passkey);
      await fixture.auth.initialize();

      final result = await fixture.auth.signInWithPasskey(
        loginHint: 'ana@example.com',
      );

      expect(
        result.errorOrNull,
        isA<PasskeyFailed>().having(
          (error) => error.reason,
          'reason',
          PasskeyFailureReason.userCancelled,
        ),
      );
    });
  });
}
