import 'dart:async';

import 'package:flutter/material.dart';
import 'package:loginflow_auth/src/sign_in/l10n/login_flow_strings_context.dart';
import 'package:loginflow_auth/src/sign_in/model/passkeys_phase.dart';
import 'package:loginflow_auth/src/sign_in/model/passkeys_state.dart';
import 'package:loginflow_auth/src/sign_in/ui/widget/passkey_list_step.dart';
import 'package:loginflow_auth/src/sign_in/ui/widget/passkeys_reauthentication_step.dart';
import 'package:loginflow_auth/src/sign_in/ui/widget/sign_in_message_step.dart';
import 'package:loginflow_auth/src/sign_in/viewmodel/passkeys_viewmodel.dart';

/// Shows the step for the current manager phase. Routing only.
class PasskeysStepView extends StatelessWidget {
  const PasskeysStepView({
    required this.state,
    required this.viewModel,
    this.username,
    this.displayName,
    super.key,
  });

  final PasskeysState state;
  final PasskeysViewModel viewModel;
  final String? username;
  final String? displayName;

  @override
  Widget build(BuildContext context) {
    final strings = context.loginFlowStrings;
    return switch (state.phase) {
      PasskeysNotConfigured() => SignInMessageStep(
        message: strings.notConfigured,
      ),
      PasskeysSignedOut() => SignInMessageStep(
        message: strings.passkeysSignedOut,
      ),
      PasskeysLoading() => const SizedBox.shrink(),
      PasskeysLoadFailed() => SignInMessageStep(
        message: strings.passkeysLoadFailed,
        actionLabel: strings.tryAgain,
        onAction: state.isBusy ? null : () => unawaited(viewModel.retry()),
      ),
      PasskeysListed(:final passkeys) => PasskeyListStep(
        passkeys: passkeys,
        state: state,
        viewModel: viewModel,
        username: username,
        displayName: displayName,
      ),
      PasskeysReauthenticating() => PasskeysReauthenticationStep(
        state: state,
        viewModel: viewModel,
      ),
    };
  }
}
