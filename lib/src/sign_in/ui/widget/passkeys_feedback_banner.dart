import 'package:flutter/material.dart';
import 'package:loginflow_auth/src/sign_in/l10n/login_flow_strings_context.dart';
import 'package:loginflow_auth/src/sign_in/model/passkeys_feedback.dart';
import 'package:loginflow_auth/src/sign_in/ui/presentation/passkeys_presentation.dart';
import 'package:loginflow_auth/src/sign_in/ui/widget/sign_in_error_banner.dart';

/// The passkey manager's current message, announced to screen readers.
class PasskeysFeedbackBanner extends StatelessWidget {
  const PasskeysFeedbackBanner({required this.feedback, super.key});

  final PasskeysFeedback feedback;

  @override
  Widget build(BuildContext context) {
    final message = feedback.toMessage(context.loginFlowStrings);
    if (message == null) {
      return const SizedBox.shrink();
    }
    return SignInErrorBanner(message: message);
  }
}
