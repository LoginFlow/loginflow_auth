import 'package:flutter/material.dart';
import 'package:loginflow_auth/src/sign_in/ui/sign_in_keys.dart';
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

/// "Sign in with a passkey", shown on the method picker and on every
/// single-method entry screen (password, email code) so an app configured
/// with one primary method still offers passkeys.
class PasskeyButton extends StatelessWidget {
  const PasskeyButton({required this.label, required this.onPressed, super.key});

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => OutlinedButton.icon(
    key: SignInKeys.passkeyButton,
    style: OutlinedButton.styleFrom(
      minimumSize: Size.fromHeight(context.signInTheme.actionHeight),
    ),
    onPressed: onPressed,
    icon: const Icon(Icons.key_outlined),
    label: Text(label),
  );
}

/// "Sign in with Apple", black-on-white per the Apple Human Interface
/// Guidelines (the "Black" variant: a filled black pill with the Apple mark
/// and white label text — `developer.apple.com/design/human-interface-
/// guidelines/sign-in-with-apple`).
class AppleSignInButton extends StatelessWidget {
  const AppleSignInButton({
    required this.label,
    required this.onPressed,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => ElevatedButton.icon(
    key: SignInKeys.appleButton,
    style: ElevatedButton.styleFrom(
      backgroundColor: Colors.black,
      foregroundColor: Colors.white,
      disabledBackgroundColor: Colors.black38,
      disabledForegroundColor: Colors.white70,
      minimumSize: Size.fromHeight(context.signInTheme.actionHeight),
      shape: const StadiumBorder(),
    ),
    onPressed: onPressed,
    icon: const Icon(Icons.apple),
    label: Text(label),
  );
}

/// "Continue with Facebook", Facebook blue per the Meta brand guidelines
/// (`developers.facebook.com/docs/facebook-login/web/login-button`): a
/// filled `#1877F2` button with white label text.
class FacebookSignInButton extends StatelessWidget {
  const FacebookSignInButton({
    required this.label,
    required this.onPressed,
    super.key,
  });

  static const Color brandColor = Color(0xFF1877F2);

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => ElevatedButton.icon(
    key: SignInKeys.facebookButton,
    style: ElevatedButton.styleFrom(
      backgroundColor: brandColor,
      foregroundColor: Colors.white,
      disabledBackgroundColor: brandColor.withValues(alpha: 0.38),
      disabledForegroundColor: Colors.white70,
      minimumSize: Size.fromHeight(context.signInTheme.actionHeight),
    ),
    onPressed: onPressed,
    icon: const Icon(Icons.facebook),
    label: Text(label),
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
