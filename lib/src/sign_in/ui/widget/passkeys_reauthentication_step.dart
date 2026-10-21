import 'dart:async';

import 'package:flutter/material.dart';
import 'package:loginflow_auth/src/sign_in/l10n/login_flow_strings_context.dart';
import 'package:loginflow_auth/src/sign_in/model/passkeys_state.dart';
import 'package:loginflow_auth/src/sign_in/model/sign_in_state.dart';
import 'package:loginflow_auth/src/sign_in/service/sign_in_service.dart';
import 'package:loginflow_auth/src/sign_in/ui/sign_in_keys.dart';
import 'package:loginflow_auth/src/sign_in/ui/theme/login_flow_sign_in_theme.dart';
import 'package:loginflow_auth/src/sign_in/ui/widget/sign_in_buttons.dart';
import 'package:loginflow_auth/src/sign_in/ui/widget/sign_in_feedback_banner.dart';
import 'package:loginflow_auth/src/sign_in/ui/widget/sign_in_step_view.dart';
import 'package:loginflow_auth/src/sign_in/viewmodel/passkeys_viewmodel.dart';
import 'package:loginflow_auth/src/sign_in/viewmodel/sign_in_viewmodel.dart';
import 'package:reactive_notifier/reactive_notifier.dart';

/// "Confirm it's you": the server asked for a recent sign-in before adding
/// a passkey. The steps are the bundled sign-in UI's own, driven by the
/// sign-in ViewModel, which follows the step-up challenge
/// `PasskeysViewModel` opened; the passkey is added once it completes.
class PasskeysReauthenticationStep extends StatelessWidget {
  const PasskeysReauthenticationStep({
    required this.state,
    required this.viewModel,
    super.key,
  });

  final PasskeysState state;
  final PasskeysViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final strings = context.loginFlowStrings;
    final spacing = context.signInTheme.spacingMedium;
    return Column(
      crossAxisAlignment: .stretch,
      spacing: spacing,
      children: [
        Semantics(
          header: true,
          child: Text(
            strings.reauthenticateTitle,
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        Text(strings.reauthenticateMessage),
        ReactiveViewModelBuilder<SignInViewModel, SignInState>(
          viewmodel: SignInService.flow.notifier,
          build: (signInState, signIn, keep) => Column(
            crossAxisAlignment: .stretch,
            spacing: spacing,
            children: [
              SignInFeedbackBanner(feedback: signInState.feedback),
              SignInStepView(state: signInState, viewModel: signIn),
            ],
          ),
        ),
        SignInTextAction(
          key: SignInKeys.passkeysCancelReauthentication,
          label: strings.cancelButton,
          onPressed: state.isBusy
              ? null
              : () => unawaited(viewModel.cancelReauthentication()),
        ),
      ],
    );
  }
}
