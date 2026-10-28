import 'dart:async';

import 'package:flutter/material.dart';
import 'package:loginflow_auth/src/sign_in/l10n/login_flow_strings_context.dart';
import 'package:loginflow_auth/src/sign_in/model/sign_in_phase.dart';
import 'package:loginflow_auth/src/sign_in/model/sign_in_state.dart';
import 'package:loginflow_auth/src/sign_in/ui/presentation/sign_in_presentation.dart';
import 'package:loginflow_auth/src/sign_in/ui/theme/login_flow_sign_in_theme.dart';
import 'package:loginflow_auth/src/sign_in/ui/widget/code_field.dart';
import 'package:loginflow_auth/src/sign_in/ui/widget/sign_in_buttons.dart';
import 'package:loginflow_auth/src/sign_in/viewmodel/sign_in_viewmodel.dart';

/// The emailed code of an in-app password reset, with a resend cooldown.
/// "Back" leaves the reset.
class ResetCodeStep extends StatefulWidget {
  const ResetCodeStep({
    required this.phase,
    required this.state,
    required this.viewModel,
    super.key,
  });

  final SignInResetCodeEntry phase;
  final SignInState state;
  final SignInViewModel viewModel;

  @override
  State<ResetCodeStep> createState() => _ResetCodeStepState();
}

class _ResetCodeStepState extends State<ResetCodeStep> {
  final TextEditingController _code = TextEditingController();

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  void _submit() => unawaited(widget.viewModel.submitResetCode(_code.text));

  @override
  Widget build(BuildContext context) {
    final strings = context.loginFlowStrings;
    final phase = widget.phase;
    final isEnabled = !widget.state.isBusy;
    return Column(
      crossAxisAlignment: .stretch,
      spacing: context.signInTheme.spacingMedium,
      children: [
        Semantics(
          header: true,
          child: Text(
            strings.resetPasswordTitle,
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        Text(strings.resetCodeSentTo(phase.email)),
        CodeField(
          controller: _code,
          label: strings.codeLabel,
          isEnabled: isEnabled,
          isNumeric: true,
          onSubmitted: _submit,
          errorText: widget.state.codeError.toCodeMessage(strings),
        ),
        SignInPrimaryButton(
          label: strings.verifyButton,
          onPressed: isEnabled ? _submit : null,
        ),
        SignInTextAction(
          label: phase.canResend
              ? strings.resendCode
              : strings.resendIn(phase.resendSecondsLeft),
          onPressed: isEnabled && phase.canResend
              ? () => unawaited(widget.viewModel.resendResetCode())
              : null,
        ),
        SignInTextAction(
          label: strings.back,
          onPressed: isEnabled
              ? () => unawaited(widget.viewModel.cancelPasswordReset())
              : null,
        ),
      ],
    );
  }
}
