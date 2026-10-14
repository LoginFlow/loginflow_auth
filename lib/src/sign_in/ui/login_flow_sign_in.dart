import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:loginflow_auth/src/core/session/login_flow_session.dart';
import 'package:loginflow_auth/src/integrations/device/device.dart';
import 'package:loginflow_auth/src/sign_in/model/sign_in_phase.dart';
import 'package:loginflow_auth/src/sign_in/service/sign_in_service.dart';
import 'package:loginflow_auth/src/sign_in/ui/desktop/sign_in_screen_desktop.dart';
import 'package:loginflow_auth/src/sign_in/ui/mobile/sign_in_screen_mobile.dart';

/// The ready-to-use sign-in flow. Install it once with
/// `LoginFlowSignInSetup.install`, then show this widget as a route.
/// [onSignedIn] runs once each time the flow completes.
class LoginFlowSignIn extends StatefulWidget {
  const LoginFlowSignIn({required this.onSignedIn, this.logo, super.key});

  final ValueChanged<LoginFlowSession> onSignedIn;

  /// Brand mark shown above the title.
  final Widget? logo;

  @override
  State<LoginFlowSignIn> createState() => _LoginFlowSignInState();
}

class _LoginFlowSignInState extends State<LoginFlowSignIn> {
  bool _hasNotified = false;

  @override
  void initState() {
    super.initState();
    SignInService.flow.notifier.addListener(_onFlowChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) => _onFlowChanged());
  }

  @override
  void dispose() {
    SignInService.flow.notifier.removeListener(_onFlowChanged);
    super.dispose();
  }

  /// Delivers completion to the app once; the decision that the flow is
  /// complete was already taken by the ViewModel.
  void _onFlowChanged() {
    if (!mounted) {
      return;
    }
    final phase = SignInService.flow.notifier.data.phase;
    if (phase case SignInCompleted(:final session)) {
      if (!_hasNotified) {
        _hasNotified = true;
        TextInput.finishAutofillContext();
        widget.onSignedIn(session);
      }
      return;
    }
    _hasNotified = false;
  }

  @override
  Widget build(BuildContext context) => DeviceLayout(
    mobile: SignInScreenMobile(logo: widget.logo),
    tablet: SignInScreenDesktop(logo: widget.logo),
    desktop: SignInScreenDesktop(logo: widget.logo),
  );
}
