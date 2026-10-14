import 'package:flutter/material.dart';
import 'package:loginflow_auth/src/sign_in/l10n/login_flow_strings_context.dart';
import 'package:loginflow_auth/src/sign_in/model/sign_in_copy.dart';
import 'package:loginflow_auth/src/sign_in/ui/presentation/sign_in_presentation.dart';
import 'package:loginflow_auth/src/sign_in/ui/theme/login_flow_sign_in_theme.dart';

/// Logo, title and subtitle.
class SignInHeader extends StatelessWidget {
  const SignInHeader({required this.copy, this.logo, super.key});

  final SignInCopy copy;
  final Widget? logo;

  @override
  Widget build(BuildContext context) {
    final strings = context.loginFlowStrings;
    final languageCode = context.languageCode;
    final theme = context.signInTheme;
    final textTheme = Theme.of(context).textTheme;
    return Column(
      spacing: theme.spacingSmall,
      children: [
        if (logo case final logo?)
          SizedBox(height: theme.logoHeight, child: logo),
        Semantics(
          header: true,
          child: Text(
            copy.toTitle(strings, languageCode),
            style: textTheme.headlineSmall,
            textAlign: .center,
          ),
        ),
        Text(
          copy.toSubtitle(strings, languageCode),
          style: textTheme.bodyMedium,
          textAlign: .center,
        ),
      ],
    );
  }
}
