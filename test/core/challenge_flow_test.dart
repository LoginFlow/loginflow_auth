import 'package:flutter_test/flutter_test.dart';
import 'package:loginflow_auth/loginflow_auth_core.dart';

import '../support/auth_fixture.dart';
import '../support/fake_google_source.dart';
import '../support/fake_login_flow_server.dart';
import '../support/test_signing_keys.dart';

void main() {
  late TestSigningKeys keys;
  late FakeLoginFlowServer server;

  setUpAll(() => keys = TestSigningKeys.generate());

  setUp(() async => server = await FakeLoginFlowServer.start(keys));

  tearDown(() => server.close());

  group('Challenge flow (first-party-apps draft-04)', () {
    test(
      'password sign-in ends in a validated session and stored tokens',
      () async {
        final fixture = AuthFixture.create(server);
        await fixture.auth.initialize();

        final result = await fixture.auth.signInWithPassword(
          loginHint: 'ana@example.com',
          password: 'correct-horse',
        );

        final state = result.data;
        expect(state, isA<SignedIn>());
        final identity = (state as SignedIn).session.identity;
        expect(identity.subject, 'cu_ana');
        expect(identity.companyId, FakeLoginFlowServer.companyId);
        expect(identity.sessionId, startsWith('sid_'));

        final first = server.challengeRequests.single;
        expect(first['client_id'], 'app-one');
        expect(first['response_type'], 'code');
        expect(first['code_challenge_method'], 'S256');
        expect(first['code_challenge'], hasLength(43));
        expect(first['scope'], contains('openid'));
        expect(first['scope'], contains('offline_access'));
        expect(first['ui_locales'], 'es en');

        final tokenRequest = server.tokenRequests.single;
        expect(tokenRequest['grant_type'], 'authorization_code');
        expect(
          PkcePair.challengeFor(tokenRequest['code_verifier']!),
          first['code_challenge'],
        );
        // The code is bound to the opening's redirect_uri: the redemption
        // presents that same value, or the real server answers
        // `redirect_uri mismatch`.
        expect(first['redirect_uri'], isNotNull);
        expect(tokenRequest['redirect_uri'], first['redirect_uri']);

        final stored = await fixture.storedSession();
        expect(stored?.refreshToken, startsWith('rt_'));
        // One request opened and completed the transaction: the server's
        // `200` carries only the code, never an `auth_session`, so a later
        // step-up identifies the user with the ID token instead.
        expect(stored?.authSession, isNull);
        expect(
          (await fixture.auth.accessTokenFor(FakeLoginFlowServer.routesApi))
              .isOk,
          isTrue,
        );
      },
    );

    test('choosing password on select_method prompts for it without a '
        'request: the server has no method=password step', () async {
      final fixture = AuthFixture.create(server);
      await fixture.auth.initialize();
      await fixture.auth.beginSignIn(loginHint: 'ana@example.com');
      final sent = server.challengeRequests.length;

      final chosen = await fixture.auth.selectMethod(ChallengeStep.password);

      final prompt = (chosen.data as ChallengeRequired).prompt;
      expect(prompt.step, ChallengeStep.password);
      expect(prompt.loginHint, 'ana@example.com');
      expect(server.challengeRequests, hasLength(sent));
      final done = await fixture.auth.submitPassword('correct-horse');
      expect(done.data, isA<SignedIn>());
    });

    test('choosing the recovery code on a TOTP step prompts for it without a '
        'request, and the code completes the sign-in', () async {
      final fixture = AuthFixture.create(server);
      await fixture.auth.initialize();
      await fixture.auth.signInWithPassword(
        loginHint: 'tomas@example.com',
        password: 'battery-staple',
      );
      final sent = server.challengeRequests.length;

      final chosen = await fixture.auth.selectMethod(
        ChallengeStep.recoveryCode,
      );

      expect(
        (chosen.data as ChallengeRequired).prompt.step,
        ChallengeStep.recoveryCode,
      );
      expect(server.challengeRequests, hasLength(sent));
      final done = await fixture.auth.submitRecoveryCode(
        FakeLoginFlowServer.recoveryCode,
      );
      expect(done.data, isA<SignedIn>());
    });

    test('a wrong password keeps the user on the password step', () async {
      final fixture = AuthFixture.create(server);
      await fixture.auth.initialize();

      final result = await fixture.auth.signInWithPassword(
        loginHint: 'ana@example.com',
        password: 'wrong',
      );

      expect(
        result.data,
        isA<ChallengeRequired>().having(
          (state) => state.prompt,
          'prompt',
          const ChallengePrompt(
            step: ChallengeStep.password,
            alternatives: <ChallengeStep>[
              ChallengeStep.password,
              ChallengeStep.emailOtp,
            ],
            stepError: StepError.invalidCredential,
            loginHint: 'ana@example.com',
          ),
        ),
      );
      expect(server.tokenRequests, isEmpty);

      final retry = await fixture.auth.submitPassword('correct-horse');

      expect(retry.data, isA<SignedIn>());
      final second = server.challengeRequests.last;
      expect(second['auth_session'], isNotNull);
      expect(second.containsKey('code_challenge'), isFalse);
    });

    test('email OTP: request, wrong code, resend, right code', () async {
      final fixture = AuthFixture.create(server);
      await fixture.auth.initialize();

      final requested = await fixture.auth.requestEmailOtp(
        loginHint: 'ana@example.com',
      );
      expect(
        (requested.data as ChallengeRequired).prompt.step,
        ChallengeStep.emailOtp,
      );
      expect(server.sentEmailOtps, <String>['ana@example.com']);

      final wrong = await fixture.auth.submitEmailOtp('000000');
      expect(
        (wrong.data as ChallengeRequired).prompt.stepError,
        StepError.invalidCredential,
      );

      await fixture.auth.resendEmailOtp();
      expect(server.sentEmailOtps, hasLength(2));

      final signedIn = await fixture.auth.submitEmailOtp(
        FakeLoginFlowServer.emailOtpCode,
      );
      expect(signedIn.data, isA<SignedIn>());
    });

    test('magic link: request sends the OTP email and the token signs in, a '
        'wrong token does not', () async {
      final fixture = AuthFixture.create(server);
      await fixture.auth.initialize();

      final requested = await fixture.auth.requestEmailOtp(
        loginHint: 'ana@example.com',
      );
      expect(
        (requested.data as ChallengeRequired).prompt.step,
        ChallengeStep.emailOtp,
      );

      final afterMagicLinkRequest = await fixture.auth.requestMagicLink();
      expect(
        (afterMagicLinkRequest.data as ChallengeRequired).prompt.step,
        ChallengeStep.emailOtp,
        reason:
            'the server always answers next: email_otp for a magic-link '
            'request — the code on the same step still works',
      );
      expect(server.sentMagicLinks, <String>['ana@example.com']);

      final wrongToken = await fixture.auth.submitMagicLinkToken(
        'not-the-real-token',
      );
      expect(
        (wrongToken.data as ChallengeRequired).prompt.stepError,
        StepError.invalidCredential,
      );

      final signedIn = await fixture.auth.submitMagicLinkToken(
        FakeLoginFlowServer.magicLinkToken,
      );
      expect(signedIn.data, isA<SignedIn>());
    });

    test('TOTP is asked after the password when the account has it', () async {
      final fixture = AuthFixture.create(server);
      await fixture.auth.initialize();

      final afterPassword = await fixture.auth.signInWithPassword(
        loginHint: 'tomas@example.com',
        password: 'battery-staple',
      );
      final prompt = (afterPassword.data as ChallengeRequired).prompt;
      expect(prompt.step, ChallengeStep.totp);
      expect(prompt.alternatives, contains(ChallengeStep.recoveryCode));

      final wrong = await fixture.auth.submitTotp('999999');
      expect(
        (wrong.data as ChallengeRequired).prompt.stepError,
        StepError.invalidCredential,
      );

      final signedIn = await fixture.auth.submitTotp(
        FakeLoginFlowServer.totpCode,
      );
      expect((signedIn.data as SignedIn).session.identity.subject, 'cu_tomas');
    });

    test('a recovery code can replace the TOTP', () async {
      final fixture = AuthFixture.create(server);
      await fixture.auth.initialize();
      await fixture.auth.signInWithPassword(
        loginHint: 'tomas@example.com',
        password: 'battery-staple',
      );

      final signedIn = await fixture.auth.submitRecoveryCode(
        FakeLoginFlowServer.recoveryCode,
      );

      expect(signedIn.data, isA<SignedIn>());
    });

    test('a strong step-up opens on the kept auth_session, asks the primary '
        'factor again, then the TOTP, and keeps the same subject', () async {
      final fixture = AuthFixture.create(server);
      await fixture.auth.initialize();
      await fixture.auth.signInWithPassword(
        loginHint: 'tomas@example.com',
        password: 'battery-staple',
      );
      await fixture.auth.submitTotp(FakeLoginFlowServer.totpCode);
      final storedBefore = await fixture.storedSession();
      // The completed transaction keeps the auth_session the TOTP step
      // presented as its step-up handle.
      expect(
        storedBefore?.authSession,
        server.challengeRequests.last['auth_session'],
      );

      final stepUp = await fixture.auth.stepUp(
        const StepUpRequirement(
          acrValues: <String>['urn:loginflow:acr:phr', 'urn:loginflow:acr:mfa'],
          maxAge: Duration(minutes: 5),
        ),
      );
      final required = stepUp.data as ChallengeRequired;
      expect(required.purpose, ChallengePurpose.stepUp);
      expect(required.prompt.step, ChallengeStep.password);
      final stepUpRequest = server.challengeRequests.last;
      expect(stepUpRequest['auth_session'], storedBefore?.authSession);
      expect(
        stepUpRequest['acr_values'],
        'urn:loginflow:acr:phr urn:loginflow:acr:mfa',
      );
      expect(stepUpRequest['code_challenge'], isNotNull);

      final second = await fixture.auth.submitPassword('battery-staple');
      expect(
        (second.data as ChallengeRequired).prompt.step,
        ChallengeStep.totp,
      );
      final done = await fixture.auth.submitTotp(FakeLoginFlowServer.totpCode);

      expect((done.data as SignedIn).session.identity.subject, 'cu_tomas');
      expect(server.tokenRequests, hasLength(2));
    });

    test('a step-up whose stored auth_session the server no longer knows '
        'retries once with id_token_hint', () async {
      final fixture = AuthFixture.create(server);
      await fixture.auth.initialize();
      await fixture.auth.signInWithPassword(
        loginHint: 'ana@example.com',
        password: 'correct-horse',
      );
      // The real server answers `invalid_session` for a stored auth_session
      // it cannot trace back to a live session (one that came from a
      // browser or hosted flow): loginflow_api challenge_handler.rs step-up
      // opening, `subject_behind_auth_session`.
      server.expireChallengeSessions();

      final stepUp = await fixture.auth.stepUp(
        const StepUpRequirement(maxAge: Duration(minutes: 5)),
      );

      final required = stepUp.data as ChallengeRequired;
      expect(required.purpose, ChallengePurpose.stepUp);
      expect(required.prompt.step, ChallengeStep.password);
      final retry = server.challengeRequests.last;
      expect(retry.containsKey('auth_session'), isFalse);
      expect(retry['id_token_hint'], isNotNull);
      expect(retry['max_age'], '300');

      final done = await fixture.auth.submitPassword('correct-horse');
      expect((done.data as SignedIn).session.identity.subject, 'cu_ana');
    });

    test('an expired auth_session restarts the sign-in', () async {
      final fixture = AuthFixture.create(server);
      await fixture.auth.initialize();
      await fixture.auth.requestEmailOtp(loginHint: 'ana@example.com');
      server.expireChallengeSessions();

      final result = await fixture.auth.submitEmailOtp('424242');

      expect(
        result.data,
        const SignedOut(reason: SignOutReason.challengeExpired),
      );
      final again = await fixture.auth.submitEmailOtp('424242');
      expect(again.errorOrNull, const NoChallengeInProgress());
    });

    test(
      'Google natively: the server nonce reaches the SDK and back',
      () async {
        final google = FakeGoogleSource();
        final fixture = AuthFixture.create(server, google: google);
        await fixture.auth.initialize();

        final result = await fixture.auth.signInWithGoogle();

        expect(result.data, isA<SignedIn>());
        final prompt = google.prompts.single;
        expect(prompt.clientId, FakeLoginFlowServer.googleWebClientId);
        expect(server.challengeRequests.first['upstream_flow'], 'native');
        expect(
          server.challengeRequests.last['upstream_token'],
          'google:${prompt.nonce}:ana@example.com',
        );
      },
    );

    test('a cancelled Google sheet returns to signed out', () async {
      final google = FakeGoogleSource()..shouldCancel = true;
      final fixture = AuthFixture.create(server, google: google);
      await fixture.auth.initialize();

      final result = await fixture.auth.signInWithGoogle();

      expect(
        result.errorOrNull,
        const UpstreamFailed(
          provider: UpstreamProvider.google,
          reason: UpstreamFailureReason.cancelled,
        ),
      );
      expect(fixture.auth.state, const SignedOut());
    });

    test('login options come from the server for this client', () async {
      server.loginMethods = <String>['password', 'google'];
      final fixture = AuthFixture.create(server);

      final options = await fixture.auth.fetchLoginOptions();

      expect(options.data.loginMethods, <String>['password', 'google']);
      expect(options.data.clientId, 'app-one');
    });
  });

  group('Server contract adjustments (phases 5/5b)', () {
    test('an opening request with no method answers select_method with the '
        "client's primary methods", () async {
      final fixture = AuthFixture.create(server);
      await fixture.auth.initialize();

      final opened = await fixture.auth.beginSignIn(
        loginHint: 'ana@example.com',
      );

      final prompt = (opened.data as ChallengeRequired).prompt;
      expect(prompt.step, ChallengeStep.selectMethod);
      expect(
        prompt.alternatives,
        containsAll(<ChallengeStep>[
          ChallengeStep.password,
          ChallengeStep.emailOtp,
        ]),
      );

      final chosen = await fixture.auth.selectMethod(ChallengeStep.emailOtp);
      expect(
        (chosen.data as ChallengeRequired).prompt.step,
        ChallengeStep.emailOtp,
      );
      final done = await fixture.auth.submitEmailOtp(
        FakeLoginFlowServer.emailOtpCode,
      );
      expect(done.data, isA<SignedIn>());
    });

    test("each step's alternatives are the real server's `methods`: primary "
        'methods in contract order, the password step from the client '
        'alone', () async {
      // `magic_link` is in neither list and `passkey` only allows the
      // password step's `webauthn_identify`
      // (`loginflow_api/src/features/login_engine/service/challenge_service.rs:1694-1718`).
      server.loginMethods = <String>[
        'magic_link',
        'apple',
        'password',
        'passkey',
      ];
      final fixture = AuthFixture.create(server);
      await fixture.auth.initialize();

      final opened = await fixture.auth.beginSignIn(
        loginHint: 'ana@example.com',
      );
      expect(
        (opened.data as ChallengeRequired).prompt.alternatives,
        <ChallengeStep>[ChallengeStep.password],
      );

      final wrong = await fixture.auth.submitPassword('not-the-password');
      expect(
        (wrong.data as ChallengeRequired).prompt.alternatives,
        <ChallengeStep>[ChallengeStep.password, ChallengeStep.webauthnIdentify],
      );
    });

    test('a passkey in the login methods is no first factor while the '
        'company policy keeps passkeys as a second factor', () async {
      // The real server lets `passkey` allow `webauthn_identify` only under a
      // `passwordless` policy
      // (`loginflow_api/src/features/oidc_provider/service/client_registry_service.rs:714-718`).
      server
        ..loginMethods = <String>['password', 'passkey']
        ..passkeyMode = PasskeyMode.mfaOnly;
      final fixture = AuthFixture.create(server);
      await fixture.auth.initialize();
      await fixture.auth.beginSignIn(loginHint: 'ana@example.com');

      final wrong = await fixture.auth.submitPassword('not-the-password');

      expect(
        (wrong.data as ChallengeRequired).prompt.alternatives,
        <ChallengeStep>[ChallengeStep.password],
      );
    });

    test('a step-up asks to select a method when the client no longer '
        'allows passwords', () async {
      final fixture = AuthFixture.create(server);
      await fixture.auth.initialize();
      await fixture.auth.signInWithPassword(
        loginHint: 'ana@example.com',
        password: 'correct-horse',
      );
      // The real step-up opening answers `select_method` when the client's
      // methods do not allow `password`
      // (`loginflow_api/src/features/login_engine/engine.rs:115-117`).
      server.loginMethods = <String>['email_otp'];

      final stepUp = await fixture.auth.stepUp(
        const StepUpRequirement(maxAge: Duration(minutes: 5)),
      );

      final prompt = (stepUp.data as ChallengeRequired).prompt;
      expect(prompt.step, ChallengeStep.selectMethod);
      expect(prompt.alternatives, <ChallengeStep>[ChallengeStep.emailOtp]);
    });

    test('id_token_hint only identifies the user: the step-up still asks '
        'for the primary factor first', () async {
      final shared = InMemorySsoStore();
      final appOne = AuthFixture.create(server, ssoStore: shared);
      await appOne.auth.initialize();
      await appOne.auth.signInWithPassword(
        loginHint: 'ana@example.com',
        password: 'correct-horse',
      );
      final appTwo = AuthFixture.create(
        server,
        clientId: 'app-two',
        ssoStore: shared,
      );
      await appTwo.auth.initialize();
      await appTwo.auth.continueWithSso();

      final stepUp = await appTwo.auth.stepUp(
        const StepUpRequirement(acrValues: <String>['mfa']),
      );

      expect(server.challengeRequests.last['id_token_hint'], isNotNull);
      expect(
        (stepUp.data as ChallengeRequired).prompt.step,
        ChallengeStep.password,
      );
      final afterPassword = await appTwo.auth.submitPassword('correct-horse');
      expect(
        (afterPassword.data as ChallengeRequired).prompt.step,
        ChallengeStep.totp,
      );
      final done = await appTwo.auth.submitTotp(FakeLoginFlowServer.totpCode);
      expect((done.data as SignedIn).session.identity.subject, 'cu_ana');
    });

    test("revoking another client's refresh token is refused and the local "
        'sign-out still completes', () async {
      final shared = InMemorySsoStore();
      final appOne = AuthFixture.create(server, ssoStore: shared);
      await appOne.auth.initialize();
      await appOne.auth.signInWithPassword(
        loginHint: 'ana@example.com',
        password: 'correct-horse',
      );
      final appTwo = AuthFixture.create(
        server,
        clientId: 'app-two',
        ssoStore: shared,
      );
      await appTwo.auth.initialize();
      await appTwo.auth.continueWithSso();
      final mixedUp = InMemorySessionStore();
      await mixedUp.write((await appTwo.storedSession())!);
      final confused = AuthFixture.create(server, sessionStore: mixedUp);
      await confused.auth.initialize();

      final signedOut = await confused.auth.signOut(SignOutScope.app);

      expect(
        signedOut.data,
        const SignedOut(reason: SignOutReason.userRequested),
      );
      expect(await confused.storedSession(), isNull);
      appTwo.clock.advance(const Duration(minutes: 15));
      expect(
        (await appTwo.auth.accessTokenFor(FakeLoginFlowServer.routesApi)).isOk,
        isTrue,
      );
    });
  });
}
