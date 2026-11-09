// Requirement: LoginFlow answers an email-code request the same whether or
// not an email left, and refuses a new code for a while once one was
// issued; the library owns the wait before "resend" so no app re-implements
// it.
// Oracle: the public `ChallengePrompt.resendAvailableAt`, the `Result` of
// `resendEmailOtp`, and the requests the fake server received.
// Risk edge: a resend that reaches the server too early (nothing is sent,
// the user is stuck), or a wrong code that restarts the countdown.
// Counterfactual: without the local guard the early resend reaches the
// fake server (`challengeRequests` grows) and comes back `Ok`.
import 'package:flutter_test/flutter_test.dart';
import 'package:loginflow_auth/loginflow_auth_core.dart';

import '../support/auth_fixture.dart';
import '../support/fake_login_flow_server.dart';
import '../support/test_signing_keys.dart';

void main() {
  late TestSigningKeys keys;
  late FakeLoginFlowServer server;

  setUpAll(() => keys = TestSigningKeys.generate());

  setUp(() async => server = await FakeLoginFlowServer.start(keys));

  tearDown(() => server.close());

  const cooldown = LoginFlowConfig.defaultEmailCodeResendCooldown;

  ChallengePrompt promptOf(Result<AuthState, LoginFlowError> result) =>
      (result.data as ChallengeRequired).prompt;

  Future<AuthFixture> codeRequested() async {
    final fixture = AuthFixture.create(server);
    await fixture.auth.initialize();
    await fixture.auth.requestEmailOtp(loginHint: 'ana@example.com');
    return fixture;
  }

  group('LoginFlowConfig.emailCodeResendCooldown', () {
    final config = LoginFlowConfig(
      issuer: Uri.parse('https://auth.example.com'),
      clientId: 'app-one',
    );

    test('defaults to 60 seconds', () {
      expect(config.emailCodeResendCooldown, const Duration(seconds: 60));
    });

    test('validate refuses a cooldown that is not positive', () {
      expect(
        config
            .copyWith(emailCodeResendCooldown: Duration.zero)
            .validate()
            .errorOrNull,
        isA<ConfigurationInvalid>(),
      );
      expect(config.validate().errorOrNull, isNull);
    });

    test('survives its JSON form', () {
      final custom = config.copyWith(
        emailCodeResendCooldown: const Duration(seconds: 90),
      );

      expect(LoginFlowConfig.fromJson(custom.toJson()), custom);
    });
  });

  group('Email code resend countdown', () {
    test(
      'requesting a code sets resendAvailableAt one cooldown ahead',
      () async {
        final fixture = AuthFixture.create(server);
        await fixture.auth.initialize();
        final sentAt = fixture.clock.now();

        final requested = await fixture.auth.requestEmailOtp(
          loginHint: 'ana@example.com',
        );

        expect(promptOf(requested).resendAvailableAt, sentAt.add(cooldown));
        expect(fixture.auth.emailOtpResendWait, cooldown);
      },
    );

    test('resend before the cooldown fails with RateLimited and sends no '
        'request', () async {
      final fixture = await codeRequested();
      final requestsBefore = server.challengeRequests.length;
      final stateBefore = fixture.auth.state;
      fixture.clock.advance(const Duration(seconds: 18));

      final resent = await fixture.auth.resendEmailOtp();

      expect(
        resent.errorOrNull,
        const RateLimited(retryAfter: Duration(seconds: 42)),
      );
      expect(server.challengeRequests, hasLength(requestsBefore));
      expect(server.sentEmailOtps, <String>['ana@example.com']);
      expect(fixture.auth.state, stateBefore);
    });

    test(
      'resend after the cooldown is sent and starts a new countdown',
      () async {
        final fixture = await codeRequested();
        fixture.clock.advance(cooldown);
        final resentAt = fixture.clock.now();

        final resent = await fixture.auth.resendEmailOtp();

        expect(server.challengeRequests.last['resend'], 'email_otp');
        expect(server.sentEmailOtps, hasLength(2));
        expect(promptOf(resent).resendAvailableAt, resentAt.add(cooldown));
        expect(
          (fixture.auth.state as ChallengeRequired).prompt.resendAvailableAt,
          resentAt.add(cooldown),
        );
      },
    );

    test('a wrong code keeps the countdown running', () async {
      final fixture = await codeRequested();
      final availableAt =
          (fixture.auth.state as ChallengeRequired).prompt.resendAvailableAt;
      fixture.clock.advance(const Duration(seconds: 20));

      final wrong = await fixture.auth.submitEmailOtp('000000');

      expect(promptOf(wrong).stepError, StepError.invalidCredential);
      expect(promptOf(wrong).resendAvailableAt, availableAt);
      expect(
        (await fixture.auth.resendEmailOtp()).errorOrNull,
        const RateLimited(retryAfter: Duration(seconds: 40)),
      );
    });

    test(
      'cancel clears the countdown and a new sign-in starts its own',
      () async {
        final fixture = await codeRequested();

        await fixture.auth.cancelChallenge();

        expect(fixture.auth.emailOtpResendWait, Duration.zero);
        expect(
          (await fixture.auth.resendEmailOtp()).errorOrNull,
          const NoChallengeInProgress(),
        );
        fixture.clock.advance(const Duration(seconds: 10));
        final again = await fixture.auth.requestEmailOtp(
          loginHint: 'ana@example.com',
        );
        expect(
          promptOf(again).resendAvailableAt,
          fixture.clock.now().add(cooldown),
        );
      },
    );

    test(
      'a step that is not the email code has no resendAvailableAt',
      () async {
        final fixture = AuthFixture.create(server);
        await fixture.auth.initialize();

        final password = await fixture.auth.beginSignIn(
          loginHint: 'ana@example.com',
        );

        expect(promptOf(password).step, isNot(ChallengeStep.emailOtp));
        expect(promptOf(password).resendAvailableAt, isNull);
        expect(fixture.auth.emailOtpResendWait, Duration.zero);
      },
    );

    test('ChallengePrompt keeps resendAvailableAt through its JSON form', () {
      final prompt = ChallengePrompt(
        step: ChallengeStep.emailOtp,
        loginHint: 'ana@example.com',
        resendAvailableAt: DateTime.utc(2026, 11, 10, 9, 0, 42),
      );

      expect(ChallengePrompt.fromJson(prompt.toJson()), prompt);
      expect(
        prompt,
        isNot(prompt.copyWith(resendAvailableAt: DateTime.utc(2026))),
      );
    });
  });
}
