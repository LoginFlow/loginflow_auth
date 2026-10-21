import 'package:flutter/material.dart';
import 'package:loginflow_auth/src/sign_in/l10n/login_flow_strings_context.dart';
import 'package:loginflow_auth/src/sign_in/ui/sign_in_keys.dart';

/// Confirms deleting the passkey called [name]; pops `true` to delete.
class PasskeyDeleteDialog extends StatelessWidget {
  const PasskeyDeleteDialog({required this.name, super.key});

  final String name;

  @override
  Widget build(BuildContext context) {
    final strings = context.loginFlowStrings;
    final colors = Theme.of(context).colorScheme;
    return AlertDialog(
      title: Text(strings.deletePasskeyTitle),
      content: Text(strings.deletePasskeyMessage(name)),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(strings.cancelButton),
        ),
        FilledButton(
          key: SignInKeys.passkeyDialogConfirm,
          style: FilledButton.styleFrom(
            backgroundColor: colors.error,
            foregroundColor: colors.onError,
          ),
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(strings.deletePasskey),
        ),
      ],
    );
  }
}
