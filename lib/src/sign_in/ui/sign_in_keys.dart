import 'package:flutter/foundation.dart';

/// Stable keys of the sign-in UI, for widget tests and integration drivers.
abstract final class SignInKeys {
  static const ValueKey<String> emailField = ValueKey<String>(
    'loginflow.field.email',
  );
  static const ValueKey<String> passwordField = ValueKey<String>(
    'loginflow.field.password',
  );
  static const ValueKey<String> codeField = ValueKey<String>(
    'loginflow.field.code',
  );
  static const ValueKey<String> passwordStep = ValueKey<String>(
    'loginflow.step.password',
  );
  static const ValueKey<String> emailStep = ValueKey<String>(
    'loginflow.step.email',
  );
  static const ValueKey<String> otpStep = ValueKey<String>(
    'loginflow.step.otp',
  );
  static const String totpStepPrefix = 'loginflow.step.totp';
  static const String methodButtonPrefix = 'loginflow.method';
  static const ValueKey<String> temporaryAccessPassStep = ValueKey<String>(
    'loginflow.step.temporary_access_pass',
  );
  static const ValueKey<String> accessCodeStep = ValueKey<String>(
    'loginflow.step.access_code',
  );
  static const ValueKey<String> accessCodeField = ValueKey<String>(
    'loginflow.field.access_code',
  );
  static const ValueKey<String> useAccessCodeButton = ValueKey<String>(
    'loginflow.button.access_code',
  );
  static const ValueKey<String> useEmailCodeButton = ValueKey<String>(
    'loginflow.button.email_code',
  );
  static const ValueKey<String> passkeyButton = ValueKey<String>(
    'loginflow.button.passkey',
  );
  static const ValueKey<String> appleButton = ValueKey<String>(
    'loginflow.button.apple',
  );
  static const ValueKey<String> facebookButton = ValueKey<String>(
    'loginflow.button.facebook',
  );
  static const ValueKey<String> passkeysAddButton = ValueKey<String>(
    'loginflow.passkeys.add',
  );
  static const String passkeyRenamePrefix = 'loginflow.passkeys.rename';
  static const String passkeyDeletePrefix = 'loginflow.passkeys.delete';
  static const ValueKey<String> passkeyNameField = ValueKey<String>(
    'loginflow.passkeys.field.name',
  );
  static const ValueKey<String> passkeyDialogConfirm = ValueKey<String>(
    'loginflow.passkeys.dialog.confirm',
  );
  static const ValueKey<String> passkeysCancelReauthentication =
      ValueKey<String>('loginflow.passkeys.reauthentication.cancel');
}
