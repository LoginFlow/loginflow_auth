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

/// Authenticator (TOTP) or recovery code entry, shown whenever the server
/// asks for the second factor.
class TotpStep extends StatefulWidget {
  const TotpStep({
    required this.phase,
    required this.state,
    required this.viewModel,
    super.key,
  });

  final SignInTotpEntry phase;
  final SignInState state;
  final SignInViewModel viewModel;

  @override
  State<TotpStep> createState() => _TotpStepState();
}

class _TotpStepState extends State<TotpStep> {
  final TextEditingController _code = TextEditingController();

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  void _submit() => unawaited(widget.viewModel.submitSecondFactor(_code.text));

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
            strings.twoStepTitle,
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        Text(
          phase.isRecoveryCode
              ? strings.recoveryInstructions
              : strings.authenticatorInstructions,
        ),
        CodeField(
          controller: _code,
          label: strings.codeLabel,
          isEnabled: isEnabled,
          isNumeric: !phase.isRecoveryCode,
          onSubmitted: _submit,
          errorText: widget.state.codeError.toCodeMessage(strings),
        ),
        SignInPrimaryButton(
          label: strings.verifyButton,
          onPressed: isEnabled ? _submit : null,
        ),
        if (phase.canUseRecoveryCode)
          SignInTextAction(
            label: phase.isRecoveryCode
                ? strings.useAuthenticatorCode
                : strings.useRecoveryCode,
            onPressed: isEnabled ? widget.viewModel.toggleRecoveryCode : null,
          ),
        if (widget.state.canGoBack)
          SignInTextAction(
            label: strings.back,
            onPressed: isEnabled
                ? () => unawaited(widget.viewModel.goBack())
                : null,
          ),
      ],
    );
  }
}
