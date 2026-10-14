import 'package:flutter/material.dart';
import 'package:loginflow_auth/src/sign_in/ui/widget/sign_in_panel.dart';

/// Phones: the flow fills the screen and scrolls above the keyboard.
class SignInScreenMobile extends StatelessWidget {
  const SignInScreenMobile({this.logo, super.key});

  final Widget? logo;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: SingleChildScrollView(child: SignInPanel(logo: logo)),
    ),
  );
}
