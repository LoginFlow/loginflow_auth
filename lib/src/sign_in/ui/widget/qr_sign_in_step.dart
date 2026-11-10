import 'dart:async';

import 'package:flutter/material.dart';
import 'package:loginflow_auth/src/sign_in/l10n/login_flow_strings_context.dart';
import 'package:loginflow_auth/src/sign_in/model/sign_in_phase.dart';
import 'package:loginflow_auth/src/sign_in/model/sign_in_state.dart';
import 'package:loginflow_auth/src/sign_in/ui/presentation/sign_in_presentation.dart';
import 'package:loginflow_auth/src/sign_in/ui/sign_in_keys.dart';
import 'package:loginflow_auth/src/sign_in/ui/theme/login_flow_sign_in_theme.dart';
import 'package:loginflow_auth/src/sign_in/ui/widget/sign_in_buttons.dart';
import 'package:loginflow_auth/src/sign_in/ui/widget/sign_in_qr_code.dart';
import 'package:loginflow_auth/src/sign_in/viewmodel/sign_in_viewmodel.dart';

/// The sign-in QR to scan with a phone already signed in, with its
/// countdown; once it was refused or expired, "Show a new code".
class QrSignInStep extends StatelessWidget {
  const QrSignInStep({
    required this.phase,
    required this.state,
    required this.viewModel,
    super.key,
  });

  final SignInQrWaiting phase;
  final SignInState state;
  final SignInViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final strings = context.loginFlowStrings;
    final qrUri = phase.qrUri;
    final isEnabled = !state.isBusy;
    return Column(
      crossAxisAlignment: .stretch,
      spacing: context.signInTheme.spacingMedium,
      children: [
        if (qrUri != null) ...[
          Text(strings.qrSignInInstructions, textAlign: .center),
          Center(
            child: SignInQrCode(
              key: SignInKeys.qrSignInCode,
              data: qrUri.toString(),
              semanticLabel: strings.qrCodeLabel,
            ),
          ),
          Text(phase.toExpiryLabel(strings), textAlign: .center),
        ] else
          SignInPrimaryButton(
            key: SignInKeys.deviceSignInAgainButton,
            label: strings.qrSignInNewCode,
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
