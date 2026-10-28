import 'package:flutter_test/flutter_test.dart';
import 'package:loginflow_auth/loginflow_auth.dart';
import 'package:loginflow_auth/src/sign_in/model/field_error.dart';
import 'package:loginflow_auth/src/sign_in/model/sign_in_feedback.dart';
import 'package:loginflow_auth/src/sign_in/model/sign_in_phase.dart';
import 'package:loginflow_auth/src/sign_in/service/sign_in_service.dart';
import 'package:loginflow_auth/src/sign_in/viewmodel/sign_in_viewmodel.dart';

import '../support/fake_login_flow_server.dart';
import '../support/fake_passkey_authenticator.dart';
import '../support/sign_in_harness.dart';
import '../support/test_signing_keys.dart';

const String _luz = 'luz@example.com';
const String _luzPassword = 'Luz-Password-1';
const String _newPassword = 'N3w-Passw0rd!';

/// "Forgot your password?" of the bundled sign-in UI: the in-app reset of
/// `LoginFlowAuth` (code, new password typed twice, then signed in), never
/// the browser.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late TestSigningKeys keys;
  late FakeLoginFlowServer server;

  setUpAll(() => keys = TestSigningKeys.generate());

  setUp(() {
    server = FakeLoginFlowServer.inMemory(keys);
    server.users[_luz] = const FakeUser(
      subject: 'cu_luz',
      email: _luz,
      password: _luzPassword,
      name: 'Luz Mar',
    );
  });

  SignInViewModel viewModel() => SignInService.flow.notifier;

  /// Waits until the ViewModel rests on a phase of type [T].
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

  /// The password step of a client whose only method is the password, with
  /// every state of its `LoginFlowAuth` recorded.
  Future<(SignInHarness, List<AuthState>)> onPasswordStep({
    PasskeyAuthenticator? passkey,
  }) async {
    final harness = SignInHarness.install(
      server,
      const SignInConfiguration(
        methods: <AuthMethod>[PasswordMethod()],
        isPasskeySignInOffered: true,
      ),
      passkey: passkey,
    );
    final states = <AuthState>[];
    harness.auth.states.listen(states.add);
    await harness.auth.initialize();
    viewModel();
    await phaseOf<SignInPasswordEntry>();
    return (harness, states);
  }

  /// The reset of [email] past its code, on the new password.
  Future<void> onNewPassword(String email) async {
    await viewModel().forgotPassword(email);
    await phaseOf<SignInResetCodeEntry>();
    await viewModel().submitResetCode(FakeLoginFlowServer.emailOtpCode);
    await phaseOf<SignInNewPasswordEntry>();
  }

  // TEST_CHARTER
  // Requirement: "Forgot your password?" runs the in-app reset: the code
  // step for the email typed, the new password typed twice, then the
  // sign-in completes — never through the browser, never signed in before
  // the password is saved.
  // Oracle: the phases, the auth states, the change-password request and no
  // `intent` on any challenge request.
  // Risk edge: the old browser hand-off (`SignInAwaitingBrowser`), or the
  // code's session completing the sign-in screen.
  // Layer: ViewModel over a real `LoginFlowAuth` and the fake LoginFlow.
  // Counterfactual: mapping `AwaitingNewPassword` to `SignInCompleted`.
  test('forgot password: code, new password twice, then signed in', () async {
    final (_, states) = await onPasswordStep();

    await viewModel().forgotPassword(' $_luz ');
    final code = await phaseOf<SignInResetCodeEntry>();
    expect(code.email, _luz);
    await viewModel().submitResetCode(FakeLoginFlowServer.emailOtpCode);
    final newPassword = await phaseOf<SignInNewPasswordEntry>();
    expect(newPassword.email, _luz);
    expect(states.whereType<SignedIn>(), isEmpty);

    await viewModel().setNewPassword(
      password: _newPassword,
      repeatedPassword: _newPassword,
    );

    await phaseOf<SignInCompleted>();
    expect(server.changePasswordRequests, hasLength(1));
    expect(
      server.challengeRequests.where((form) => form.containsKey('intent')),
      isEmpty,
    );
  });

  // TEST_CHARTER
  // Requirement: the reset needs a valid email; one missing or malformed is
  // refused on the field, with no request.
  // Oracle: the email field error and the requests the server received.
  // Risk edge: a reset started for an empty address.
  // Layer: ViewModel.
  // Counterfactual: sending the address as typed.
  test(
    'forgot password with no valid email -> field error, no request',
    () async {
      await onPasswordStep();

      await viewModel().forgotPassword('luz@');

      expect(viewModel().data.emailError, FieldError.invalidEmail);
      expect(server.challengeRequests, isEmpty);
    },
  );

  // TEST_CHARTER
  // Requirement: a wrong code says so and stays on the code step.
  // Oracle: the feedback and the phase.
  // Risk edge: `InvalidResetCode` shown as the generic error.
  // Layer: ViewModel over the fake LoginFlow.
  // Counterfactual: mapping every reset error to `unexpected`.
  test('a wrong code -> invalidCredential, still on the code', () async {
    await onPasswordStep();
    await viewModel().forgotPassword(_luz);
    await phaseOf<SignInResetCodeEntry>();

    await viewModel().submitResetCode('000000');

    await phaseOf<SignInResetCodeEntry>();
    expect(viewModel().data.feedback, SignInFeedback.invalidCredential);
  });

  // TEST_CHARTER
  // Requirement: the two passwords must match before anything is sent.
  // Oracle: the repeated-password field error, no change-password request.
  // Risk edge: a typo saved as the new password.
  // Layer: ViewModel.
  // Counterfactual: sending the first password regardless.
  test('passwords that differ -> field error, nothing sent', () async {
    await onPasswordStep();
    await onNewPassword(_luz);

    await viewModel().setNewPassword(
      password: _newPassword,
      repeatedPassword: '${_newPassword}x',
    );

    expect(viewModel().data.repeatedPasswordError, FieldError.passwordMismatch);
    expect(server.changePasswordRequests, isEmpty);
  });

  // TEST_CHARTER
  // Requirement: a refused password says why and stays on the new password.
  // Oracle: the feedback and the phase.
  // Risk edge: `PasswordRejected` shown as the generic error, or the reset
  // dropped.
  // Layer: ViewModel over the fake LoginFlow.
  // Counterfactual: mapping `PasswordRejected` to `unexpected`.
  test('a refused password -> passwordRejected, still on it', () async {
    await onPasswordStep();
    await onNewPassword(_luz);

    await viewModel().setNewPassword(
      password: 'short',
      repeatedPassword: 'short',
    );

    await phaseOf<SignInNewPasswordEntry>();
    expect(viewModel().data.feedback, SignInFeedback.passwordRejected);
  });

  // TEST_CHARTER
  // Requirement: "Back" from the code or the new password leaves the reset:
  // back to the password step, signed out, the held session revoked.
  // Oracle: the phase, the auth state, the revocation the server received.
  // Risk edge: a held session left alive, or the reset still open.
  // Layer: ViewModel over the fake LoginFlow.
  // Counterfactual: `goBack` (the challenge) instead of the reset's cancel.
  test('back from the code or the new password -> the password step, '
      'signed out', () async {
    final (harness, _) = await onPasswordStep();
    await viewModel().forgotPassword(_luz);
    await phaseOf<SignInResetCodeEntry>();

    await viewModel().cancelPasswordReset();
    await phaseOf<SignInPasswordEntry>();
    expect(harness.auth.state, isA<SignedOut>());

    await onNewPassword(_luz);
    final heldToken = server.lastIssuedRefreshToken;
    await viewModel().cancelPasswordReset();

    await phaseOf<SignInPasswordEntry>();
    expect(harness.auth.state, isA<SignedOut>());
    expect(
      server.revocationRequests.map((form) => form['token']),
      contains(heldToken),
    );
  });

  // TEST_CHARTER
  // Requirement: the in-app reset needs the email code: "Forgot your
  // password?" shows only when the server enables reset AND the client's
  // login methods include `email_otp`.
  // Oracle: the password phase's flag.
  // Risk edge: a button whose every tap the server refuses.
  // Layer: ViewModel over the fake login options.
  // Counterfactual: reading `password_reset` alone.
  test('forgot password hidden when the client has no email code', () async {
    server.loginMethods = <String>['password'];
    final harness = SignInHarness.install(
      server,
      const SignInConfiguration(methods: <AuthMethod>[PasswordMethod()]),
    );
    await harness.auth.initialize();
    viewModel();

    final phase = await phaseOf<SignInPasswordEntry>();

    expect(phase.isForgotPasswordShown, isFalse);
  });

  // TEST_CHARTER
  // Requirement: the step-up a passkey account's new password needs shows
  // the password step WITHOUT "Forgot your password?", and its passkey
  // button continues that step-up (`selectMethod`) instead of opening a new
  // sign-in, so the password is set before the person is signed in.
  // Oracle: the phase flag, the change-password requests (401 then 200) and
  // the completed sign-in.
  // Risk edge: the passkey button starting a fresh sign-in that drops the
  // reset and signs in with the old password still in place.
  // Layer: ViewModel over a real `LoginFlowAuth` and the fake LoginFlow.
  // Counterfactual: `signInWithPasskey` calling `auth.signInWithPasskey`.
  test('the step-up of a passkey account: no forgot password, the passkey '
      'finishes the reset', () async {
    server.loginMethods = <String>[...server.loginMethods, 'passkey'];
    await onPasswordStep(passkey: FakePasskeyAuthenticator());
    await onNewPassword('ana@example.com');

    await viewModel().setNewPassword(
      password: _newPassword,
      repeatedPassword: _newPassword,
    );
    final stepUp = await phaseOf<SignInPasswordEntry>();
    expect(stepUp.isForgotPasswordShown, isFalse);
    expect(stepUp.isIdentifierLocked, isTrue);

    await viewModel().signInWithPasskey();

    await phaseOf<SignInCompleted>();
    expect(server.changePasswordRequests, hasLength(2));
  });
}
