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

/// The number to pick on the phone, large, with its countdown; once it was
/// refused or expired, "Send a new request".
class PhoneApprovalStep extends StatelessWidget {
  const PhoneApprovalStep({
    required this.phase,
    required this.state,
    required this.viewModel,
    super.key,
  });

  final SignInPhoneApprovalWaiting phase;
  final SignInState state;
  final SignInViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final strings = context.loginFlowStrings;
    final number = phase.number;
    final isEnabled = !state.isBusy;
    return Column(
      crossAxisAlignment: .stretch,
      spacing: context.signInTheme.spacingMedium,
      children: [
        if (number != null) ...[
          Text(strings.phoneApprovalInstructions, textAlign: .center),
          Text(
            '$number',
            key: SignInKeys.phoneApprovalNumber,
            textAlign: .center,
            style: Theme.of(context).textTheme.displayLarge,
          ),
          Text(phase.toExpiryLabel(strings), textAlign: .center),
        ] else
          SignInPrimaryButton(
            key: SignInKeys.deviceSignInAgainButton,
            label: strings.phoneApprovalAskAgain,
            onPressed: isEnabled
                ? () => unawaited(viewModel.tryDeviceSignInAgain())
                : null,
          ),
        if (state.canGoBack)
          SignInTextAction(
            label: strings.back,
            onPressed: isEnabled ? () => unawaited(viewModel.goBack()) : null,
          ),
      ],
    );
  }
}
