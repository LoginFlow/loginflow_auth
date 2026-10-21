import 'package:flutter/material.dart';
import 'package:loginflow_auth/src/sign_in/l10n/login_flow_strings_context.dart';
import 'package:loginflow_auth/src/sign_in/ui/theme/login_flow_sign_in_theme.dart';
import 'package:loginflow_auth/src/sign_in/ui/widget/passkeys_panel.dart';

/// Tablets and desktops: the manager sits in a centered card of bounded
/// width, like the sign-in flow.
class PasskeysScreenDesktop extends StatelessWidget {
  const PasskeysScreenDesktop({this.username, this.displayName, super.key});

  final String? username;
  final String? displayName;

  @override
  Widget build(BuildContext context) {
    final theme = context.signInTheme;
    return Scaffold(
      appBar: AppBar(title: Text(context.loginFlowStrings.passkeysTitle)),
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
              child: PasskeysPanel(
                username: username,
                displayName: displayName,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
