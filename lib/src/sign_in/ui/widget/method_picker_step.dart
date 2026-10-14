import 'dart:async';

import 'package:flutter/material.dart';
import 'package:loginflow_auth/src/sign_in/l10n/login_flow_strings_context.dart';
import 'package:loginflow_auth/src/sign_in/model/auth_method.dart';
import 'package:loginflow_auth/src/sign_in/model/sign_in_phase.dart';
import 'package:loginflow_auth/src/sign_in/model/sign_in_state.dart';
import 'package:loginflow_auth/src/sign_in/ui/presentation/sign_in_presentation.dart';
import 'package:loginflow_auth/src/sign_in/ui/theme/login_flow_sign_in_theme.dart';
import 'package:loginflow_auth/src/sign_in/ui/widget/sign_in_buttons.dart';
import 'package:loginflow_auth/src/sign_in/viewmodel/sign_in_viewmodel.dart';

/// One button per available method, in configured order.
class MethodPickerStep extends StatelessWidget {
  const MethodPickerStep({
    required this.phase,
    required this.state,
    required this.viewModel,
    super.key,
  });

  final SignInChoosingMethod phase;
  final SignInState state;
  final SignInViewModel viewModel;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: .stretch,
    spacing: context.signInTheme.spacingSmall,
    children: [
      ...phase.methods.map(
        (method) => _MethodButton(
          key: method.toButtonKey(),
          method: method,
          onPressed: state.isBusy ? null : () => viewModel.chooseMethod(method),
        ),
      ),
      if (state.isSignUpOffered)
        SignInTextAction(
          label: context.loginFlowStrings.createAccount,
          onPressed: state.isBusy ? null : () => unawaited(viewModel.signUp()),
        ),
    ],
  );
}

class _MethodButton extends StatelessWidget {
  const _MethodButton({
    required this.method,
    required this.onPressed,
    super.key,
  });

  final AuthMethod method;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final icon = method.toIcon();
    return OutlinedButton.icon(
      style: OutlinedButton.styleFrom(
        minimumSize: Size.fromHeight(context.signInTheme.actionHeight),
      ),
      onPressed: onPressed,
      icon: icon == null ? null : Icon(icon),
      label: Text(method.toButtonLabel(context.loginFlowStrings)),
    );
  }
}
