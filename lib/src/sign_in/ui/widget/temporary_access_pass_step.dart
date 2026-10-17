import 'dart:async';

import 'package:flutter/material.dart';
import 'package:loginflow_auth/src/sign_in/l10n/login_flow_strings_context.dart';
import 'package:loginflow_auth/src/sign_in/model/sign_in_phase.dart';
import 'package:loginflow_auth/src/sign_in/model/sign_in_state.dart';
import 'package:loginflow_auth/src/sign_in/ui/presentation/sign_in_presentation.dart';
import 'package:loginflow_auth/src/sign_in/ui/sign_in_keys.dart';
import 'package:loginflow_auth/src/sign_in/ui/theme/login_flow_sign_in_theme.dart';
import 'package:loginflow_auth/src/sign_in/ui/widget/code_field.dart';
import 'package:loginflow_auth/src/sign_in/ui/widget/sign_in_buttons.dart';
import 'package:loginflow_auth/src/sign_in/viewmodel/sign_in_viewmodel.dart';

/// Temporary Access Pass entry: an admin-issued, single-use recovery code,
/// reached through [SignInViewModel.useTemporaryAccessPass].
class TemporaryAccessPassStep extends StatefulWidget {
  const TemporaryAccessPassStep({
    required this.phase,
    required this.state,
    required this.viewModel,
    super.key,
  });

  final SignInTemporaryAccessPassEntry phase;
  final SignInState state;
  final SignInViewModel viewModel;

  @override
  State<TemporaryAccessPassStep> createState() =>
      _TemporaryAccessPassStepState();
}

class _TemporaryAccessPassStepState extends State<TemporaryAccessPassStep> {
  late final TextEditingController _email = TextEditingController(
    text: widget.state.rememberedEmail,
  );
  final TextEditingController _code = TextEditingController();

  @override
  void dispose() {
    _email.dispose();
    _code.dispose();
    super.dispose();
  }

  void _submit() => unawaited(
    widget.viewModel.submitTemporaryAccessPass(
      email: _email.text,
      code: _code.text,
    ),
  );

  @override
  Widget build(BuildContext context) {
    final strings = context.loginFlowStrings;
    final state = widget.state;
    final isEnabled = !state.isBusy;
    return Column(
      crossAxisAlignment: .stretch,
      spacing: context.signInTheme.spacingMedium,
      children: [
        Semantics(
          header: true,
          child: Text(
            strings.temporaryAccessPassTitle,
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        Text(strings.temporaryAccessPassInstructions),
        if (!widget.phase.isIdentifierLocked)
          TextField(
            key: SignInKeys.emailField,
            controller: _email,
            enabled: isEnabled,
            keyboardType: .emailAddress,
            textInputAction: .next,
            autofillHints: const [AutofillHints.email],
            decoration: InputDecoration(
              labelText: strings.emailLabel,
              errorText: state.emailError.toEmailMessage(strings),
            ),
          ),
        CodeField(
          controller: _code,
          label: strings.codeLabel,
          isEnabled: isEnabled,
          isNumeric: false,
          onSubmitted: _submit,
          errorText: state.codeError.toCodeMessage(strings),
        ),
        SignInPrimaryButton(
          label: strings.verifyButton,
          onPressed: isEnabled ? _submit : null,
        ),
        if (state.canGoBack)
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
