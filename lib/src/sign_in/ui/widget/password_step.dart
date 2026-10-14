import 'dart:async';

import 'package:flutter/material.dart';
import 'package:loginflow_auth/src/sign_in/l10n/login_flow_strings_context.dart';
import 'package:loginflow_auth/src/sign_in/model/sign_in_phase.dart';
import 'package:loginflow_auth/src/sign_in/model/sign_in_state.dart';
import 'package:loginflow_auth/src/sign_in/ui/presentation/sign_in_presentation.dart';
import 'package:loginflow_auth/src/sign_in/ui/sign_in_keys.dart';
import 'package:loginflow_auth/src/sign_in/ui/theme/login_flow_sign_in_theme.dart';
import 'package:loginflow_auth/src/sign_in/ui/widget/sign_in_buttons.dart';
import 'package:loginflow_auth/src/sign_in/viewmodel/sign_in_viewmodel.dart';

/// Email + password form with autofill hints for password managers.
class PasswordStep extends StatefulWidget {
  const PasswordStep({
    required this.phase,
    required this.state,
    required this.viewModel,
    super.key,
  });

  final SignInPasswordEntry phase;
  final SignInState state;
  final SignInViewModel viewModel;

  @override
  State<PasswordStep> createState() => _PasswordStepState();
}

class _PasswordStepState extends State<PasswordStep> {
  late final TextEditingController _email = TextEditingController(
    text: widget.state.rememberedEmail,
  );
  final TextEditingController _password = TextEditingController();
  bool _isObscured = true;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  void _submit() => unawaited(
    widget.viewModel.submitPassword(
      email: _email.text,
      password: _password.text,
    ),
  );

  @override
  Widget build(BuildContext context) {
    final strings = context.loginFlowStrings;
    final state = widget.state;
    final isEnabled = !state.isBusy;
    return AutofillGroup(
      child: Column(
        crossAxisAlignment: .stretch,
        spacing: context.signInTheme.spacingMedium,
        children: [
          TextField(
            key: SignInKeys.emailField,
            controller: _email,
            enabled: isEnabled && !widget.phase.isIdentifierLocked,
            keyboardType: .emailAddress,
            textInputAction: .next,
            autofillHints: const [AutofillHints.email, AutofillHints.username],
            decoration: InputDecoration(
              labelText: strings.emailLabel,
              errorText: state.emailError.toEmailMessage(strings),
            ),
          ),
          TextField(
            key: SignInKeys.passwordField,
            controller: _password,
            enabled: isEnabled,
            obscureText: _isObscured,
            textInputAction: .done,
            autofillHints: const [AutofillHints.password],
            onSubmitted: (_) => _submit(),
            decoration: InputDecoration(
              labelText: strings.passwordLabel,
              errorText: state.passwordError.toPasswordMessage(strings),
              suffixIcon: IconButton(
                tooltip: _isObscured
                    ? strings.showPassword
                    : strings.hidePassword,
                icon: Icon(
                  _isObscured ? Icons.visibility : Icons.visibility_off,
                ),
                onPressed: () => setState(() => _isObscured = !_isObscured),
              ),
            ),
          ),
          if (widget.phase.isForgotPasswordShown)
            Align(
              alignment: .centerRight,
              child: SignInTextAction(
                label: strings.forgotPassword,
                onPressed: isEnabled
                    ? () => unawaited(
                        widget.viewModel.forgotPassword(_email.text),
                      )
                    : null,
              ),
            ),
          SignInPrimaryButton(
            label: strings.signInButton,
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
      ),
    );
  }
}
