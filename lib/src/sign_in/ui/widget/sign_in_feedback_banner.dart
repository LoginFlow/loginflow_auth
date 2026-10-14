import 'package:flutter/material.dart';
import 'package:loginflow_auth/src/sign_in/l10n/login_flow_strings_context.dart';
import 'package:loginflow_auth/src/sign_in/model/sign_in_feedback.dart';
import 'package:loginflow_auth/src/sign_in/ui/presentation/sign_in_presentation.dart';
import 'package:loginflow_auth/src/sign_in/ui/theme/login_flow_sign_in_theme.dart';

/// The current message, announced to screen readers when it appears.
class SignInFeedbackBanner extends StatelessWidget {
  const SignInFeedbackBanner({required this.feedback, super.key});

  final SignInFeedback feedback;

  @override
  Widget build(BuildContext context) {
    final message = feedback.toMessage(context.loginFlowStrings);
    if (message == null) {
      return const SizedBox.shrink();
    }
    final colors = Theme.of(context).colorScheme;
    final theme = context.signInTheme;
    return Semantics(
      liveRegion: true,
      child: Material(
        color: colors.errorContainer,
        borderRadius: BorderRadius.circular(theme.cornerRadius),
        child: Padding(
          padding: EdgeInsets.all(theme.spacingMedium),
          child: Text(
            message,
            style: Theme.of(context).textTheme.bodyMedium
                ?.copyWith(color: colors.onErrorContainer),
          ),
        ),
      ),
    );
  }
}
