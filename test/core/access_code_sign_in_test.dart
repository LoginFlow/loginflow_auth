// TEST_CHARTER
// Requirement: `signInWithAccessCode` redeems a single-use code a tenant
// backend issued (`doc/server-contract.md` §16) through the native
// challenge (`method=access_code`), DPoP REQUIRED, into a DPoP-bound
// session whose identity exposes `ext_sub`/`subject_kind`/`ext_profile`;
// every failure is a typed error (invalid, throttled, unavailable,
// unsupported, configuration).
// Oracle: the fake server's real dispatch and RFC 9449 proof validation
// (single-use codes are removed on redeem), the stored session's `dpopJkt`,
// and the public `SignedIn` identity — never a mock expectation. The error
// replies are the real API's, verbatim from the wire contract
// (`test/fixtures/access_code_challenge_errors.json`).
// Risk edge: a code replayed after its first use, a throttled application,
// and a client configured without DPoP (the session must be bound to the
// device key, so the library refuses before any request is sent).
// Layer: core over a real loopback HTTP server (`FakeLoginFlowServer.start`)
// — the wire format is the risk, so no transport is mocked.
// Counterfactual: a stub that never sends the challenge, or that maps every
// failure to one error, fails the success, replay and throttle cases.

import 'package:flutter_test/flutter_test.dart';
import 'package:loginflow_auth/loginflow_auth_core.dart';

import '../support/auth_fixture.dart';
import '../support/fake_login_flow_server.dart';
import '../support/test_dpop_key_store.dart';
import '../support/test_signing_keys.dart';

void main() {
  late TestSigningKeys keys;
  late FakeLoginFlowServer server;

  setUpAll(() => keys = TestSigningKeys.generate());

  setUp(() async {
    server = await FakeLoginFlowServer.start(keys)
      ..requiresDpop = true;
  });

  tearDown(() => server.close());

  Future<AuthFixture> signedOutFixture({
    bool enableDpop = true,
    SessionStore? sessionStore,
    TestDpopKeyStore? dpopKeyStore,
  }) async {
    final fixture = AuthFixture.create(
      server,
      enableDpop: enableDpop,
      sessionStore: sessionStore,
      dpopKeyStore: dpopKeyStore,
    );
    await fixture.auth.initialize();
    return fixture;
  }

  group('Access-code sign-in', () {
    test('a typed code (any case, spaces, dash) is redeemed into a DPoP-bound '
        'session exposing the subject claims', () async {
      final fixture = await signedOutFixture();

      final result = await fixture.auth.signInWithAccessCode(' k7m2-q9 px ');

      final state = result.data;
      expect(state, isA<SignedIn>());
      final identity = (state as SignedIn).session.identity;
      expect(identity.subject, 'as_driver_7');
      expect(identity.externalSubject, 'driver:7');
      expect(identity.subjectKind, AccessSubjectKind.person);
      expect(identity.subjectProfile, 'Driver');
      expect(identity.email, isNull);

      final challenge = server.challengeRequests.single;
      expect(challenge['method'], 'access_code');
      expect(challenge['access_code'], FakeLoginFlowServer.accessCode);
      expect(challenge.containsKey('login_hint'), isFalse);
      expect(server.tokenRequests.single['grant_type'], 'authorization_code');

      expect((await fixture.storedSession())?.dpopJkt, isNotNull);
      expect(server.acceptedDpopThumbprints, hasLength(2));
      expect(server.acceptedDpopThumbprints.toSet(), hasLength(1));
      expect(server.accessCodes, isEmpty, reason: 'single use');
    });

    test('the subject claims survive an app restart', () async {
      final store = InMemorySessionStore();
      final keyStore = TestDpopKeyStore();
      final first = await signedOutFixture(
        sessionStore: store,
        dpopKeyStore: keyStore,
      );
      await first.auth.signInWithAccessCode(FakeLoginFlowServer.accessCode);

      final restarted = await signedOutFixture(
        sessionStore: store,
        dpopKeyStore: keyStore,
      );

      final state = restarted.auth.state;
      expect(state, isA<SignedIn>());
      final identity = (state as SignedIn).session.identity;
      expect(identity.externalSubject, 'driver:7');
      expect(identity.subjectKind, AccessSubjectKind.person);
      expect(identity.subjectProfile, 'Driver');
    });

    test('the contract error bodies are the ones the fake server sends', () {
      expect(FakeLoginFlowServer.accessCodeErrorReplies, <String, Object?>{
        'invalid_grant': <String, Object?>{
          'status': 400,
          'retry_after': null,
          'body': <String, Object?>{
            'error': 'invalid_grant',
            'error_description':
                'the access code is invalid, expired or already used',
          },
        },
        'slow_down': <String, Object?>{
          'status': 429,
          'retry_after': '900',
          'body': <String, Object?>{
            'error': 'slow_down',
            'error_description': 'too many failed attempts',
          },
        },
        'access_codes_disabled': <String, Object?>{
          'status': 400,
          'retry_after': null,
          'body': <String, Object?>{
            'error': 'access_codes_disabled',
            'error_description':
                'access codes are disabled for this application',
          },
        },
      });
    });

    test('a code already used fails as InvalidAccessCode, like an unknown one '
        '(400 invalid_grant, the same body for both)', () async {
      final fixture = await signedOutFixture();
      await fixture.auth.signInWithAccessCode(FakeLoginFlowServer.accessCode);
      await fixture.auth.signOut(SignOutScope.app);

      final replay = await fixture.auth.signInWithAccessCode(
        FakeLoginFlowServer.accessCode,
      );
      final unknown = await fixture.auth.signInWithAccessCode('ABCD-2345');

      expect(replay.errorOrNull, const InvalidAccessCode());
      expect(unknown.errorOrNull, const InvalidAccessCode());
      expect(fixture.auth.state, isA<SignedOut>());
      expect(server.tokenRequests, hasLength(1));
    });

    test('a malformed code fails locally, without a request', () async {
      final fixture = await signedOutFixture();

      final result = await fixture.auth.signInWithAccessCode('K7M2-Q9P0');

      expect(result.errorOrNull, const InvalidAccessCode());
      expect(server.challengeRequests, isEmpty);
    });

    test('a throttled application (429 slow_down, Retry-After: 900) reports '
        'AccessCodeThrottled with the wait', () async {
      server.isAccessCodeThrottled = true;
      final fixture = await signedOutFixture();

      final result = await fixture.auth.signInWithAccessCode(
        FakeLoginFlowServer.accessCode,
      );

      expect(
        result.errorOrNull,
        const AccessCodeThrottled(retryAfter: Duration(seconds: 900)),
      );
      expect(fixture.auth.state, isA<SignedOut>());
    });

    test('an application with access codes disabled '
        '(400 access_codes_disabled) reports AccessCodesUnavailable', () async {
      server.areAccessCodesEnabled = false;
      final fixture = await signedOutFixture();

      final result = await fixture.auth.signInWithAccessCode(
        FakeLoginFlowServer.accessCode,
      );

      expect(result.errorOrNull, const AccessCodesUnavailable());
    });

    test('a server without the access_code method reports '
        'AccessCodesUnavailable instead of prompting a step', () async {
      server.implementsAccessCodes = false;
      final fixture = await signedOutFixture();

      final result = await fixture.auth.signInWithAccessCode(
        FakeLoginFlowServer.accessCode,
      );

      expect(result.errorOrNull, const AccessCodesUnavailable());
      expect(fixture.auth.state, isA<SignedOut>());
    });

    test('a server without authorization_challenge_endpoint in its discovery '
        'reports UnsupportedByServer without a request', () async {
      server.advertisesChallengeEndpoint = false;
      final fixture = await signedOutFixture();

      final result = await fixture.auth.signInWithAccessCode(
        FakeLoginFlowServer.accessCode,
      );

      expect(
        result.errorOrNull,
        const UnsupportedByServer(feature: 'authorization_challenge_endpoint'),
      );
      expect(server.challengeRequests, isEmpty);
      expect(fixture.auth.state, isA<SignedOut>());
    });

    test(
      'a client without DPoP gets a configuration error before any request',
      () async {
        final fixture = await signedOutFixture(enableDpop: false);

        final result = await fixture.auth.signInWithAccessCode(
          FakeLoginFlowServer.accessCode,
        );

        expect(result.errorOrNull, isA<ConfigurationInvalid>());
        expect(server.challengeRequests, isEmpty);
      },
    );

    test('a regular user has no access-subject claims', () async {
      final fixture = await signedOutFixture();

      final result = await fixture.auth.signInWithPassword(
        loginHint: 'ana@example.com',
        password: 'correct-horse',
      );

      final identity = (result.data as SignedIn).session.identity;
      expect(identity.externalSubject, isNull);
      expect(identity.subjectKind, isNull);
      expect(identity.subjectProfile, isNull);
    });
  });
}
