import 'package:flutter/material.dart';
import 'package:loginflow_auth/src/sign_in/ui/theme/login_flow_sign_in_theme.dart';

/// Thin linear loading bar; keeps its height when idle so nothing jumps.
class SignInProgressBar extends StatelessWidget {
  const SignInProgressBar({required this.isBusy, super.key});

  final bool isBusy;

  @override
  Widget build(BuildContext context) {
    final thickness = context.signInTheme.progressThickness;
    return SizedBox(
      height: thickness,
      child: isBusy ? LinearProgressIndicator(minHeight: thickness) : null,
    );
  }
}
