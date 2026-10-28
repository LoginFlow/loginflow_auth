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

/// The new password of an in-app password reset, typed twice, with the
/// `newPassword` autofill hint so a password manager can suggest and save
/// one. "Back" leaves the reset.
class NewPasswordStep extends StatefulWidget {
  const NewPasswordStep({
    required this.phase,
    required this.state,
    required this.viewModel,
    super.key,
  });

  final SignInNewPasswordEntry phase;
  final SignInState state;
  final SignInViewModel viewModel;

  @override
  State<NewPasswordStep> createState() => _NewPasswordStepState();
}

class _NewPasswordStepState extends State<NewPasswordStep> {
  final TextEditingController _password = TextEditingController();
  final TextEditingController _repeated = TextEditingController();
  bool _isObscured = true;

  @override
  void dispose() {
    _password.dispose();
    _repeated.dispose();
    super.dispose();
  }

  void _submit() => unawaited(
    widget.viewModel.setNewPassword(
      password: _password.text,
      repeatedPassword: _repeated.text,
    ),
  );

  void _toggleObscured() => setState(() => _isObscured = !_isObscured);

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
          Semantics(
            header: true,
            child: Text(
              strings.newPasswordTitle,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          Text(widget.phase.email),
          TextField(
            key: SignInKeys.newPasswordField,
            controller: _password,
            enabled: isEnabled,
            obscureText: _isObscured,
            textInputAction: .next,
            autofillHints: const [AutofillHints.newPassword],
            decoration: InputDecoration(
              labelText: strings.newPasswordLabel,
              errorText: state.passwordError.toPasswordMessage(strings),
              suffixIcon: IconButton(
                tooltip: _isObscured
                    ? strings.showPassword
                    : strings.hidePassword,
                icon: Icon(
                  _isObscured ? Icons.visibility : Icons.visibility_off,
                ),
                onPressed: _toggleObscured,
              ),
            ),
          ),
          TextField(
            key: SignInKeys.repeatPasswordField,
            controller: _repeated,
            enabled: isEnabled,
            obscureText: _isObscured,
            textInputAction: .done,
            autofillHints: const [AutofillHints.newPassword],
            onSubmitted: (_) => _submit(),
            decoration: InputDecoration(
              labelText: strings.repeatPasswordLabel,
              errorText: state.repeatedPasswordError.toPasswordMessage(strings),
            ),
          ),
          SignInPrimaryButton(
            label: strings.savePasswordButton,
            onPressed: isEnabled ? _submit : null,
          ),
          SignInTextAction(
            label: strings.back,
            onPressed: isEnabled
                ? () => unawaited(widget.viewModel.cancelPasswordReset())
                : null,
          ),
        ],
      ),
    );
  }
}
