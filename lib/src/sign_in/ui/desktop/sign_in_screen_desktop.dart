import 'package:flutter/material.dart';
import 'package:loginflow_auth/src/sign_in/ui/theme/login_flow_sign_in_theme.dart';
import 'package:loginflow_auth/src/sign_in/ui/widget/sign_in_panel.dart';

/// Tablets and desktops: the flow sits in a centered card of bounded width.
class SignInScreenDesktop extends StatelessWidget {
  const SignInScreenDesktop({this.logo, super.key});

  final Widget? logo;

  @override
  Widget build(BuildContext context) {
    final theme = context.signInTheme;
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(theme.spacingLarge),
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: theme.cardMaxWidth),
            child: Card(
              color:
                  theme.cardColor ??
                  Theme.of(context).colorScheme.surfaceContainerLow,
              clipBehavior: .antiAlias,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(theme.cornerRadius),
              ),
              child: SignInPanel(logo: logo),
            ),
          ),
        ),
      ),
    );
  }
}
