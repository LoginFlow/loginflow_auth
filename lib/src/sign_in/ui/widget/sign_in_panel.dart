import 'package:flutter/material.dart';
import 'package:loginflow_auth/src/sign_in/l10n/login_flow_locale_service.dart';
import 'package:loginflow_auth/src/sign_in/model/sign_in_state.dart';
import 'package:loginflow_auth/src/sign_in/service/sign_in_service.dart';
import 'package:loginflow_auth/src/sign_in/ui/theme/login_flow_sign_in_theme.dart';
import 'package:loginflow_auth/src/sign_in/ui/widget/sign_in_feedback_banner.dart';
import 'package:loginflow_auth/src/sign_in/ui/widget/sign_in_header.dart';
import 'package:loginflow_auth/src/sign_in/ui/widget/sign_in_legal_footer.dart';
import 'package:loginflow_auth/src/sign_in/ui/widget/sign_in_progress_bar.dart';
import 'package:loginflow_auth/src/sign_in/ui/widget/sign_in_step_view.dart';
import 'package:loginflow_auth/src/sign_in/viewmodel/sign_in_viewmodel.dart';
import 'package:reactive_notifier/reactive_notifier.dart';

/// The flow content shared by every screen class: loading bar, header,
/// message and current step, bound to the flow ViewModel.
///
/// Rebuilds on a locale override set through [LoginFlowLocaleService], on
/// top of the flow ViewModel it already follows — no widget below ever
/// branches on a locale itself.
class SignInPanel extends StatelessWidget {
  const SignInPanel({this.logo, super.key});

  final Widget? logo;

  @override
  Widget build(BuildContext context) {
    final theme = context.signInTheme;
    return ReactiveBuilder<Locale?>(
      notifier: LoginFlowLocaleService.instance,
      build: (_, _, _) =>
          ReactiveViewModelBuilder<SignInViewModel, SignInState>(
            viewmodel: SignInService.flow.notifier,
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
                        SignInHeader(copy: state.copy, logo: logo),
                        SignInFeedbackBanner(feedback: state.feedback),
                        SignInStepView(state: state, viewModel: viewModel),
                        if (state.policyUri != null || state.tosUri != null)
                          SignInLegalFooter(
                            policyUri: state.policyUri,
                            tosUri: state.tosUri,
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
    );
  }
}
