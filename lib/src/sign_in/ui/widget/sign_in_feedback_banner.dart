import 'package:flutter/material.dart';
import 'package:loginflow_auth/src/sign_in/l10n/login_flow_strings_context.dart';
import 'package:loginflow_auth/src/sign_in/model/sign_in_feedback.dart';
import 'package:loginflow_auth/src/sign_in/ui/presentation/sign_in_presentation.dart';
import 'package:loginflow_auth/src/sign_in/ui/widget/sign_in_error_banner.dart';

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
    return SignInErrorBanner(message: message);
  }
}
