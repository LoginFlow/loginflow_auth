import 'dart:async';

import 'package:flutter/material.dart';
import 'package:loginflow_auth/src/sign_in/l10n/login_flow_strings_context.dart';
import 'package:loginflow_auth/src/sign_in/model/sign_in_phase.dart';
import 'package:loginflow_auth/src/sign_in/model/sign_in_state.dart';
import 'package:loginflow_auth/src/sign_in/ui/presentation/sign_in_presentation.dart';
import 'package:loginflow_auth/src/sign_in/ui/theme/login_flow_sign_in_theme.dart';
import 'package:loginflow_auth/src/sign_in/ui/widget/sign_in_buttons.dart';
import 'package:loginflow_auth/src/sign_in/viewmodel/sign_in_viewmodel.dart';

/// "Continue as …" for the Native SSO session of a sibling app.
class SsoConfirmStep extends StatelessWidget {
  const SsoConfirmStep({
    required this.phase,
    required this.state,
    required this.viewModel,
    super.key,
  });

  final SignInSsoConfirm phase;
  final SignInState state;
  final SignInViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final strings = context.loginFlowStrings;
    final isEnabled = !state.isBusy;
    return Column(
      crossAxisAlignment: .stretch,
      spacing: context.signInTheme.spacingMedium,
      children: [
        Text(strings.ssoSubtitle, textAlign: .center),
        SignInPrimaryButton(
          label: strings.continueAs(phase.candidate.toDisplayName()),
          onPressed: isEnabled
              ? () => unawaited(viewModel.continueWithSso())
              : null,
        ),
        SignInTextAction(
          label: strings.useAnotherAccount,
          onPressed: isEnabled
              ? () => unawaited(viewModel.useAnotherAccount())
              : null,
        ),
      ],
    );
  }
}
