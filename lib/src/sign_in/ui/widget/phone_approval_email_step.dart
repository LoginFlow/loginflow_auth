import 'dart:async';

import 'package:flutter/material.dart';
import 'package:loginflow_auth/src/sign_in/l10n/login_flow_strings_context.dart';
import 'package:loginflow_auth/src/sign_in/model/sign_in_state.dart';
import 'package:loginflow_auth/src/sign_in/ui/presentation/sign_in_presentation.dart';
import 'package:loginflow_auth/src/sign_in/ui/sign_in_keys.dart';
import 'package:loginflow_auth/src/sign_in/ui/theme/login_flow_sign_in_theme.dart';
import 'package:loginflow_auth/src/sign_in/ui/widget/sign_in_buttons.dart';
import 'package:loginflow_auth/src/sign_in/viewmodel/sign_in_viewmodel.dart';

/// Email form that asks the app on the person's phone to approve.
class PhoneApprovalEmailStep extends StatefulWidget {
  const PhoneApprovalEmailStep({
    required this.state,
    required this.viewModel,
    super.key,
  });

  final SignInState state;
  final SignInViewModel viewModel;

  @override
  State<PhoneApprovalEmailStep> createState() => _PhoneApprovalEmailStepState();
}

class _PhoneApprovalEmailStepState extends State<PhoneApprovalEmailStep> {
  late final TextEditingController _email = TextEditingController(
    text: widget.state.rememberedEmail,
  );

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  void _submit() =>
      unawaited(widget.viewModel.requestPhoneApproval(_email.text));

  @override
  Widget build(BuildContext context) {
    final strings = context.loginFlowStrings;
    final isEnabled = !widget.state.isBusy;
    return Column(
      crossAxisAlignment: .stretch,
      spacing: context.signInTheme.spacingMedium,
      children: [
        Text(strings.phoneApprovalEmailInstructions),
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
          label: strings.phoneApprovalSendButton,
          onPressed: isEnabled ? _submit : null,
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
