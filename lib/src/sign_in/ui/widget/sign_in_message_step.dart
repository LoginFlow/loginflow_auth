import 'package:flutter/material.dart';
import 'package:loginflow_auth/src/sign_in/ui/theme/login_flow_sign_in_theme.dart';
import 'package:loginflow_auth/src/sign_in/ui/widget/sign_in_buttons.dart';

/// A centered message with an optional action: lockout, browser wait,
/// unavailable options, nothing to show.
class SignInMessageStep extends StatelessWidget {
  const SignInMessageStep({
    required this.message,
    this.title,
    this.actionLabel,
    this.onAction,
    super.key,
  });

  final String message;
  final String? title;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: .stretch,
      spacing: context.signInTheme.spacingMedium,
      children: [
        if (title case final title?) _StepHeading(text: title),
        Semantics(liveRegion: true, child: Text(message, textAlign: .center)),
        if (actionLabel case final label?)
          SignInPrimaryButton(label: label, onPressed: onAction),
      ],
    );
  }
}

class _StepHeading extends StatelessWidget {
  const _StepHeading({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) => Semantics(
    header: true,
    child: Text(
      text,
      textAlign: .center,
      style: Theme.of(context).textTheme.titleMedium,
    ),
  );
}
