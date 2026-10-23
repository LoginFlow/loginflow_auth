import 'package:flutter/material.dart';
import 'package:loginflow_auth/src/integrations/device/device.dart';
import 'package:loginflow_auth/src/sign_in/l10n/login_flow_locale_service.dart';
import 'package:loginflow_auth/src/sign_in/ui/desktop/passkeys_screen_desktop.dart';
import 'package:loginflow_auth/src/sign_in/ui/mobile/passkeys_screen_mobile.dart';
import 'package:reactive_notifier/reactive_notifier.dart';

/// The ready-to-use passkey manager of the signed-in user: lists their
/// passkeys and adds, renames and deletes them. Works with the client
/// installed once with `LoginFlowSignInSetup.install`; show it as a route.
///
/// Adding a passkey may ask the user to sign in again first (the server's
/// recent-authentication gate); that step uses the same sign-in screens as
/// `LoginFlowSignIn`, and the passkey is added right after. Themed with
/// `LoginFlowSignInTheme` and translated like the sign-in UI.
class LoginFlowPasskeys extends StatelessWidget {
  /// Creates a [LoginFlowPasskeys].
  const LoginFlowPasskeys({this.username, this.displayName, super.key});

  /// The account name the platform's passkey sheet shows for a new
  /// passkey. Defaults to the session's email, else the access-code
  /// subject's external id, else its subject.
  final String? username;

  /// The person's name the platform's passkey sheet shows. Defaults to the
  /// session's name, else [username].
  final String? displayName;

  @override
  Widget build(BuildContext context) => ReactiveBuilder<Locale?>(
    notifier: LoginFlowLocaleService.instance,
    build: (_, _, _) => DeviceLayout(
      mobile: PasskeysScreenMobile(
        username: username,
        displayName: displayName,
      ),
      tablet: PasskeysScreenDesktop(
        username: username,
        displayName: displayName,
      ),
      desktop: PasskeysScreenDesktop(
        username: username,
        displayName: displayName,
      ),
    ),
  );
}
