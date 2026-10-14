import 'dart:async';

import 'package:flutter/material.dart';
import 'package:loginflow_auth/src/sign_in/l10n/login_flow_strings_context.dart';
import 'package:loginflow_auth/src/sign_in/model/sign_in_phase.dart';
import 'package:loginflow_auth/src/sign_in/model/sign_in_state.dart';
import 'package:loginflow_auth/src/sign_in/ui/sign_in_keys.dart';
import 'package:loginflow_auth/src/sign_in/ui/widget/email_step.dart';
import 'package:loginflow_auth/src/sign_in/ui/widget/method_picker_step.dart';
import 'package:loginflow_auth/src/sign_in/ui/widget/otp_step.dart';
import 'package:loginflow_auth/src/sign_in/ui/widget/password_step.dart';
import 'package:loginflow_auth/src/sign_in/ui/widget/sign_in_message_step.dart';
import 'package:loginflow_auth/src/sign_in/ui/widget/sso_confirm_step.dart';
import 'package:loginflow_auth/src/sign_in/ui/widget/totp_step.dart';
import 'package:loginflow_auth/src/sign_in/viewmodel/sign_in_viewmodel.dart';

/// Shows the step for the current phase. Routing only.
class SignInStepView extends StatelessWidget {
  const SignInStepView({
    required this.state,
    required this.viewModel,
    super.key,
  });

  final SignInState state;
  final SignInViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final strings = context.loginFlowStrings;
    return switch (state.phase) {
      SignInNotConfigured() => SignInMessageStep(
        message: strings.notConfigured,
      ),
      SignInLoadingOptions() || SignInCompleted() => const SizedBox.shrink(),
      SignInOptionsUnavailable() => SignInMessageStep(
        message: strings.optionsUnavailable,
        actionLabel: strings.tryAgain,
        onAction: state.isBusy
            ? null
            : () => unawaited(viewModel.retryOptions()),
      ),
      SignInNoMethods() => SignInMessageStep(message: strings.noMethods),
      final SignInChoosingMethod phase => MethodPickerStep(
        phase: phase,
        state: state,
        viewModel: viewModel,
      ),
      final SignInPasswordEntry phase => PasswordStep(
        key: SignInKeys.passwordStep,
        phase: phase,
        state: state,
        viewModel: viewModel,
      ),
      SignInEmailEntry() => EmailStep(
        key: SignInKeys.emailStep,
        state: state,
        viewModel: viewModel,
      ),
      final SignInOtpEntry phase => OtpStep(
        key: SignInKeys.otpStep,
        phase: phase,
        state: state,
        viewModel: viewModel,
      ),
      final SignInTotpEntry phase => TotpStep(
        key: ValueKey<String>(
          '${SignInKeys.totpStepPrefix}.${phase.isRecoveryCode}',
        ),
        phase: phase,
        state: state,
        viewModel: viewModel,
      ),
      SignInAwaitingBrowser() => SignInMessageStep(
        message: strings.continueInBrowser,
      ),
      final SignInSsoConfirm phase => SsoConfirmStep(
        phase: phase,
        state: state,
        viewModel: viewModel,
      ),
      SignInLockedOut(:final secondsLeft) => SignInMessageStep(
        title: strings.lockedOutTitle,
        message: strings.lockedOutMessage(secondsLeft),
      ),
    };
  }
}
