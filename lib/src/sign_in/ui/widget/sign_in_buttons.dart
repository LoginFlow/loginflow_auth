import 'package:flutter/material.dart';
import 'package:loginflow_auth/src/sign_in/ui/theme/login_flow_sign_in_theme.dart';

/// The primary action of a step, full width and at least 48 dp tall.
class SignInPrimaryButton extends StatelessWidget {
  const SignInPrimaryButton({
    required this.label,
    required this.onPressed,
    super.key,
  });

  final String label;

  /// `null` disables the button (e.g. while a request is in flight).
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => FilledButton(
    style: FilledButton.styleFrom(
      minimumSize: Size.fromHeight(context.signInTheme.actionHeight),
    ),
    onPressed: onPressed,
    child: Text(label),
  );
}

/// A secondary text action ("Back", "Resend code", ...), 48 dp tall.
class SignInTextAction extends StatelessWidget {
  const SignInTextAction({
    required this.label,
    required this.onPressed,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => TextButton(
    style: TextButton.styleFrom(
      minimumSize: Size(0, context.signInTheme.actionHeight),
    ),
    onPressed: onPressed,
    child: Text(label),
  );
}
