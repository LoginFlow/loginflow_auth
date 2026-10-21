import 'package:flutter/material.dart';
import 'package:loginflow_auth/src/sign_in/l10n/login_flow_strings_context.dart';
import 'package:loginflow_auth/src/sign_in/ui/widget/passkeys_panel.dart';

/// Phones: the manager fills the screen under an app bar with the way back.
class PasskeysScreenMobile extends StatelessWidget {
  const PasskeysScreenMobile({this.username, this.displayName, super.key});

  final String? username;
  final String? displayName;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(context.loginFlowStrings.passkeysTitle)),
    body: SafeArea(
      child: SingleChildScrollView(
        child: PasskeysPanel(username: username, displayName: displayName),
      ),
    ),
  );
}
