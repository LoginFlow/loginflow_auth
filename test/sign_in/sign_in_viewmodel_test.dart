import 'package:flutter_test/flutter_test.dart';
import 'package:loginflow_auth/loginflow_auth.dart';
import 'package:loginflow_auth/src/sign_in/model/field_error.dart';
import 'package:loginflow_auth/src/sign_in/model/sign_in_phase.dart';
import 'package:loginflow_auth/src/sign_in/service/sign_in_service.dart';
import 'package:loginflow_auth/src/sign_in/viewmodel/sign_in_viewmodel.dart';

import '../support/fake_login_flow_server.dart';
import '../support/sign_in_harness.dart';
import '../support/test_clock.dart';
import '../support/test_signing_keys.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late TestSigningKeys keys;
  late FakeLoginFlowServer server;

  setUpAll(() => keys = TestSigningKeys.generate());

  setUp(() => server = FakeLoginFlowServer.inMemory(keys));

  SignInViewModel viewModel() => SignInService.flow.notifier;

  /// Waits until the ViewModel reaches a phase of type [T].
  Future<T> phaseOf<T extends SignInPhase>() async {
    for (var attempt = 0; attempt < 500; attempt++) {
      final phase = viewModel().data.phase;
      if (phase is T && !viewModel().data.isBusy) {
        return phase;
      }
      await Future<void>.delayed(const Duration(milliseconds: 2));
    }
    throw TestFailure('Never reached $T; last: ${viewModel().data.phase}');
  }

  Future<SignInHarness> installed(SignInConfiguration configuration) async {
    final harness = SignInHarness.install(server, configuration);
    await harness.auth.initialize();
    viewModel();
    return harness;
  }

  test(
    'methods = configured ∩ server, configured order, first of each kind',
    () async {
      server.loginMethods = <String>['email_otp', 'password', 'google'];
      await installed(
        const SignInConfiguration(
          methods: <AuthMethod>[
            GoogleMethod(),
            MicrosoftMethod(),
            PasswordMethod(isForgotPasswordShown: false),
            PasswordMethod(),
          ],
        ),
      );

      final phase = await phaseOf<SignInChoosingMethod>();

      expect(phase.methods, const <AuthMethod>[
        GoogleMethod(),
        PasswordMethod(isForgotPasswordShown: false),
      ]);
    },
  );

  test('a malformed email is refused locally', () async {
    await installed(
      const SignInConfiguration(methods: <AuthMethod>[EmailOtpMethod()]),
    );
    await phaseOf<SignInEmailEntry>();

    await viewModel().requestEmailCode('ana@');

    expect(viewModel().data.emailError, FieldError.invalidEmail);
    expect(server.challengeRequests, isEmpty);
  });

  test('forgot password is shown only when the server enables reset', () async {
    server.isPasswordResetEnabled = false;
    await installed(
      const SignInConfiguration(methods: <AuthMethod>[PasswordMethod()]),
    );

    final phase = await phaseOf<SignInPasswordEntry>();

    expect(phase.isForgotPasswordShown, isFalse);
  });

  test('unavailable options show nothing unverified, then recover', () async {
    server.isLoginOptionsDown = true;
    await installed(
      const SignInConfiguration(
        methods: <AuthMethod>[PasswordMethod(), GoogleMethod()],
      ),
    );
    await phaseOf<SignInOptionsUnavailable>();

    server.isLoginOptionsDown = false;
    await viewModel().retryOptions();

    expect((await phaseOf<SignInChoosingMethod>()).methods, hasLength(2));
  });

  test('a re-authentication asked on refresh opens the code step', () async {
    final clock = TestClock();
    final harness = SignInHarness.install(
      server,
      const SignInConfiguration(
        methods: <AuthMethod>[
          PasswordMethod(),
          EmailOtpMethod(resendCooldown: Duration.zero),
        ],
      ),
      clock: clock,
    );
    await harness.auth.initialize();
    await phaseOf<SignInChoosingMethod>();
    viewModel().chooseMethod(const PasswordMethod());
    await viewModel().submitPassword(
      email: 'ana@example.com',
      password: 'correct-horse',
    );
    await phaseOf<SignInCompleted>();

    server.requiresReauthenticationOnRefresh = true;
    clock.advance(const Duration(minutes: 15));
    final refresh = await harness.auth.accessTokenFor(
      FakeLoginFlowServer.routesApi,
    );

    expect(refresh.errorOrNull, const ReauthenticationRequired());
    await phaseOf<SignInOtpEntry>();
    await viewModel().submitEmailCode(FakeLoginFlowServer.emailOtpCode);
    await phaseOf<SignInCompleted>();
  });

  test('back from the code step abandons the challenge', () async {
    await installed(
      const SignInConfiguration(
        methods: <AuthMethod>[
          PasswordMethod(),
          EmailOtpMethod(resendCooldown: Duration.zero),
        ],
      ),
    );
    await phaseOf<SignInChoosingMethod>();
    viewModel().chooseMethod(const EmailOtpMethod());
    await viewModel().requestEmailCode('ana@example.com');
    await phaseOf<SignInOtpEntry>();

    await viewModel().goBack();

    await phaseOf<SignInChoosingMethod>();
    final again = await SignInService.environment.notifier.auth!.submitEmailOtp(
      FakeLoginFlowServer.emailOtpCode,
    );
    expect(again.errorOrNull, const NoChallengeInProgress());
  });
}
