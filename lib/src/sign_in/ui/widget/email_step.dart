import 'dart:async';

import 'package:flutter/material.dart';
import 'package:loginflow_auth/src/sign_in/l10n/login_flow_strings_context.dart';
import 'package:loginflow_auth/src/sign_in/model/sign_in_state.dart';
import 'package:loginflow_auth/src/sign_in/ui/presentation/sign_in_presentation.dart';
import 'package:loginflow_auth/src/sign_in/ui/sign_in_keys.dart';
import 'package:loginflow_auth/src/sign_in/ui/theme/login_flow_sign_in_theme.dart';
import 'package:loginflow_auth/src/sign_in/ui/widget/sign_in_buttons.dart';
import 'package:loginflow_auth/src/sign_in/viewmodel/sign_in_viewmodel.dart';

/// Email form that asks the server to send a one-time code.
class EmailStep extends StatefulWidget {
  const EmailStep({required this.state, required this.viewModel, super.key});

  final SignInState state;
  final SignInViewModel viewModel;

  @override
  State<EmailStep> createState() => _EmailStepState();
}

class _EmailStepState extends State<EmailStep> {
  late final TextEditingController _email = TextEditingController(
    text: widget.state.rememberedEmail,
  );

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  void _submit() => unawaited(widget.viewModel.requestEmailCode(_email.text));

  @override
  Widget build(BuildContext context) {
    final strings = context.loginFlowStrings;
    final isEnabled = !widget.state.isBusy;
    return Column(
      crossAxisAlignment: .stretch,
      spacing: context.signInTheme.spacingMedium,
      children: [
        TextField(
          key: SignInKeys.emailField,
          controller: _email,
          enabled: isEnabled,
          keyboardType: .emailAddress,
          textInputAction: .done,
          autofillHints: const [AutofillHints.email],
          onSubmitted: (_) => _submit(),
          decoration: InputDecoration(
            labelText: strings.emailLabel,
            errorText: widget.state.emailError.toEmailMessage(strings),
          ),
        ),
        SignInPrimaryButton(
          label: strings.sendCodeButton,
          onPressed: isEnabled ? _submit : null,
        ),
        if (widget.state.isPasskeySignInOffered)
          PasskeyButton(
            label: strings.continueWithPasskey,
            onPressed: isEnabled
                ? () => unawaited(widget.viewModel.signInWithPasskey())
                : null,
          ),
        if (widget.state.isAccessCodeOffered)
          SignInTextAction(
            key: SignInKeys.useAccessCodeButton,
            label: strings.useAccessCode,
            onPressed: isEnabled ? widget.viewModel.useAccessCode : null,
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
