// Core test (tdd-light) of the passkey-only sign-up
// (`doc/server-contract.md` §23, API 0.26.0).
// Requirement: `signUpWithPasskey` runs the two legs of the native challenge
// (`method=passkey_signup`, then `passkey_registration`) with the platform's
// passkey creation in between, redeems the code with the same DPoP key and
// leaves a normal session for an account without an email; a capped
// sign-up, a client not configured for it and a cancelled sheet are typed
// errors.
// Oracle: the fake server's real dispatch — RFC 9449 proofs verified on
// every leg, the code bound to the ceremony's key and redeemed only with
// it, the account it created — and the public `SignedIn` identity, the
// stored session and the `Result` error.

import 'package:flutter_test/flutter_test.dart';
import 'package:loginflow_auth/loginflow_auth_core.dart';

import '../support/auth_fixture.dart';
import '../support/fake_login_flow_server.dart';
import '../support/fake_passkey_authenticator.dart';
import '../support/test_dpop_key_store.dart';
import '../support/test_signing_keys.dart';

void main() {
  late TestSigningKeys keys;
  late FakeLoginFlowServer server;

  setUpAll(() => keys = TestSigningKeys.generate());

  setUp(() async {
    server = await FakeLoginFlowServer.start(keys)
      ..requiresDpop = true
      ..loginMethods = <String>['passkey', 'passkey_signup'];
  });

  tearDown(() => server.close());

  Future<AuthFixture> signedOutFixture({
    FakePasskeyAuthenticator? passkey,
    SessionStore? sessionStore,
    TestDpopKeyStore? dpopKeyStore,
  }) async {
    final fixture = AuthFixture.create(
      server,
      passkey: passkey ?? FakePasskeyAuthenticator(),
      enableDpop: true,
      sessionStore: sessionStore,
      dpopKeyStore: dpopKeyStore,
    );
    await fixture.auth.initialize();
    return fixture;
  }

  test('both legs and the code redemption prove the same DPoP key, and the '
      'account without an email ends signed in', () async {
    final passkey = FakePasskeyAuthenticator();
    final fixture = await signedOutFixture(passkey: passkey);

    final result = await fixture.auth.signUpWithPasskey(displayName: 'Ana');

    final state = result.data;
    expect(state, isA<SignedIn>());
    final identity = (state as SignedIn).session.identity;
    expect(identity.subject, server.passkeySignUps.single.subject);
    expect(identity.email, isNull);
    expect(identity.isEmailVerified, isFalse);
    expect(identity.name, 'Ana');

    final opening = server.challengeRequests.first;
    expect(opening['method'], 'passkey_signup');
    expect(opening['display_name'], 'Ana');
    expect(opening.containsKey('login_hint'), isFalse);
    expect(server.challengeRequests.last['passkey_registration'], isNotNull);
    final sheet =
        passkey.creationOptionsSeen.single['publicKey']!
            as Map<String, Object?>;
    expect(sheet['user'], containsPair('name', 'Ana'));

    expect(server.challengeRequests, hasLength(2));
    expect(server.tokenRequests.single['grant_type'], 'authorization_code');
    expect(server.acceptedDpopThumbprints, hasLength(3));
    expect(
      server.acceptedDpopThumbprints.toSet(),
      hasLength(1),
      reason: 'the two challenge legs and the token request prove one key',
    );
    expect((await fixture.storedSession())?.dpopJkt, isNotNull);
  });

  test('a select_method step offers it, and choosing it signs the new '
      'account in on that attempt', () async {
    final fixture = await signedOutFixture();
    final opened = await fixture.auth.beginSignIn();
    final prompt = (opened.data as ChallengeRequired).prompt;
    expect(prompt.alternatives, contains(ChallengeStep.passkeySignUp));

    final result = await fixture.auth.selectMethod(ChallengeStep.passkeySignUp);

    expect(result.data, isA<SignedIn>());
    expect(server.challengeRequests[1]['method'], 'passkey_signup');
    expect(server.challengeRequests[1]['auth_session'], isNotNull);
  });

  test(
    'the account without an email is signed in again after a restart',
    () async {
      final store = InMemorySessionStore();
      final keyStore = TestDpopKeyStore();
      final first = await signedOutFixture(
        sessionStore: store,
        dpopKeyStore: keyStore,
      );
      await first.auth.signUpWithPasskey();

      final restarted = await signedOutFixture(
        sessionStore: store,
        dpopKeyStore: keyStore,
      );

      final state = restarted.auth.state;
      expect(state, isA<SignedIn>());
      final identity = (state as SignedIn).session.identity;
      expect(identity.subject, server.passkeySignUps.single.subject);
      expect(identity.email, isNull);
      expect(identity.name, isNull);
    },
  );

  test('past the application cap the sign-up is RateLimited with the '
      'Retry-After, and no account or session exists', () async {
    server.passkeySignUpCap = 0;
    final fixture = await signedOutFixture();

    final result = await fixture.auth.signUpWithPasskey();

    expect(
      result.errorOrNull,
      const RateLimited(
        retryAfter: FakeLoginFlowServer.passkeySignUpRetryAfter,
      ),
    );
    expect(fixture.auth.state, isA<SignedOut>());
    expect(server.passkeySignUps, isEmpty);
    expect(server.tokenRequests, isEmpty);
  });

  test('a client not configured for it is PasskeySignUpUnavailable, before '
      'any ceremony', () async {
    server.loginMethods = <String>['passkey'];
    final passkey = FakePasskeyAuthenticator();
    final fixture = await signedOutFixture(passkey: passkey);

    final result = await fixture.auth.signUpWithPasskey();

    expect(result.errorOrNull, const PasskeySignUpUnavailable());
    expect(passkey.creationOptionsSeen, isEmpty);
    expect(fixture.auth.state, isA<SignedOut>());
  });

  test('the person cancelling the passkey sheet ends the attempt without an '
      'account', () async {
    final passkey = FakePasskeyAuthenticator()..shouldCancel = true;
    final fixture = await signedOutFixture(passkey: passkey);

    final result = await fixture.auth.signUpWithPasskey();

    expect(
      result.errorOrNull,
      const PasskeyFailed(reason: PasskeyFailureReason.userCancelled),
    );
    expect(server.challengeRequests, hasLength(1));
    expect(server.passkeySignUps, isEmpty);
    expect(fixture.auth.state, isA<SignedOut>());
  });

  test('without DPoP the sign-up is refused before any request', () async {
    final fixture = AuthFixture.create(
      server,
      passkey: FakePasskeyAuthenticator(),
    );
    await fixture.auth.initialize();

    final result = await fixture.auth.signUpWithPasskey();

    expect(result.errorOrNull, isA<ConfigurationInvalid>());
    expect(server.challengeRequests, isEmpty);
  });

  test('without a passkey authenticator the sign-up is refused before any '
      'request', () async {
    final fixture = AuthFixture.create(server, enableDpop: true);
    await fixture.auth.initialize();

    final result = await fixture.auth.signUpWithPasskey();

    expect(
      result.errorOrNull,
      const PasskeyFailed(reason: PasskeyFailureReason.notConfigured),
    );
    expect(server.challengeRequests, isEmpty);
  });

  group('choosing it on a select_method step is refused like the call, '
      'before any request', () {
    test('without a passkey authenticator', () async {
      final fixture = AuthFixture.create(server, enableDpop: true);
      await fixture.auth.initialize();
      await fixture.auth.beginSignIn();

      final result = await fixture.auth.selectMethod(
        ChallengeStep.passkeySignUp,
      );

      expect(
        result.errorOrNull,
        const PasskeyFailed(reason: PasskeyFailureReason.notConfigured),
      );
      expect(server.challengeRequests, hasLength(1));
    });

    test('without DPoP', () async {
      server.requiresDpop = false;
      final fixture = AuthFixture.create(
        server,
        passkey: FakePasskeyAuthenticator(),
      );
      await fixture.auth.initialize();
      await fixture.auth.beginSignIn();

      final result = await fixture.auth.selectMethod(
        ChallengeStep.passkeySignUp,
      );

      expect(result.errorOrNull, isA<ConfigurationInvalid>());
      expect(server.challengeRequests, hasLength(1));
    });
  });

  test('a registration the server refuses (step_error) is PasskeyRejected, '
      'with no account and no second ceremony', () async {
    final passkey = FakePasskeyAuthenticator()..reportsNonDiscoverable = true;
    final fixture = await signedOutFixture(passkey: passkey);

    final result = await fixture.auth.signUpWithPasskey();

    expect(result.errorOrNull, const PasskeyRejected());
    expect(passkey.creationOptionsSeen, hasLength(1));
    expect(server.challengeRequests, hasLength(2));
    expect(server.passkeySignUps, isEmpty);
    expect(server.tokenRequests, isEmpty);
    expect(fixture.auth.state, isA<SignedOut>());
  });

  test('an invalid display name (422, general envelope) is '
      'InvalidProfileName, before any ceremony', () async {
    final passkey = FakePasskeyAuthenticator();
    final fixture = await signedOutFixture(passkey: passkey);

    final result = await fixture.auth.signUpWithPasskey(displayName: 'Ana 2');

    expect(result.errorOrNull, const InvalidProfileName());
    expect(passkey.creationOptionsSeen, isEmpty);
    expect(fixture.auth.state, isA<SignedOut>());
  });

  test('an invalid display name answered in an OAuth body (422) is '
      'InvalidProfileName too', () async {
    server.refusesDisplayNameInOAuthBody = true;
    final passkey = FakePasskeyAuthenticator();
    final fixture = await signedOutFixture(passkey: passkey);

    final result = await fixture.auth.signUpWithPasskey(displayName: 'Ana 2');

    expect(result.errorOrNull, const InvalidProfileName());
    expect(passkey.creationOptionsSeen, isEmpty);
  });

  test('a server that ignores the method (before API 0.26) is '
      'PasskeySignUpUnavailable, not a select_method prompt', () async {
    server.implementsPasskeySignUp = false;
    final passkey = FakePasskeyAuthenticator();
    final fixture = await signedOutFixture(passkey: passkey);

    final result = await fixture.auth.signUpWithPasskey();

    expect(result.errorOrNull, const PasskeySignUpUnavailable());
    expect(passkey.creationOptionsSeen, isEmpty);
    expect(fixture.auth.state, isA<SignedOut>());
  });
}
