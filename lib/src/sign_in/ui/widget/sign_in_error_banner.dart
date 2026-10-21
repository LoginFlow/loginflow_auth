import 'package:flutter/material.dart';
import 'package:loginflow_auth/src/sign_in/ui/theme/login_flow_sign_in_theme.dart';

/// A message on the error container colors, announced to screen readers
/// when it appears. Shared by the sign-in flow and the passkey manager.
class SignInErrorBanner extends StatelessWidget {
  const SignInErrorBanner({required this.message, super.key});

  final String message;

  @override
  Widget build(BuildContext context) {
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
