import 'package:flutter/material.dart';
import 'package:loginflow_auth/src/sign_in/l10n/login_flow_strings_context.dart';
import 'package:loginflow_auth/src/sign_in/model/passkeys_state.dart';
import 'package:loginflow_auth/src/sign_in/service/passkeys_service.dart';
import 'package:loginflow_auth/src/sign_in/ui/theme/login_flow_sign_in_theme.dart';
import 'package:loginflow_auth/src/sign_in/ui/widget/passkeys_feedback_banner.dart';
import 'package:loginflow_auth/src/sign_in/ui/widget/passkeys_step_view.dart';
import 'package:loginflow_auth/src/sign_in/ui/widget/sign_in_progress_bar.dart';
import 'package:loginflow_auth/src/sign_in/viewmodel/passkeys_viewmodel.dart';
import 'package:reactive_notifier/reactive_notifier.dart';

/// The manager content shared by every screen class: loading bar,
/// explanation, message and current step, bound to the manager ViewModel.
class PasskeysPanel extends StatelessWidget {
  const PasskeysPanel({this.username, this.displayName, super.key});

  final String? username;
  final String? displayName;

  @override
  Widget build(BuildContext context) {
    final theme = context.signInTheme;
    return ReactiveViewModelBuilder<PasskeysViewModel, PasskeysState>(
      viewmodel: PasskeysService.manager.notifier,
      build: (state, viewModel, keep) => FocusTraversalGroup(
        child: Column(
          mainAxisSize: .min,
          crossAxisAlignment: .stretch,
          children: [
            SignInProgressBar(isBusy: state.isBusy),
            Padding(
              padding: EdgeInsets.all(theme.spacingLarge),
              child: Column(
                crossAxisAlignment: .stretch,
                spacing: theme.spacingLarge,
                children: [
                  Text(
                    context.loginFlowStrings.passkeysSubtitle,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  PasskeysFeedbackBanner(feedback: state.feedback),
                  PasskeysStepView(
                    state: state,
                    viewModel: viewModel,
                    username: username,
                    displayName: displayName,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
