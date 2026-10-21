import 'package:flutter/material.dart';
import 'package:loginflow_auth/src/sign_in/l10n/login_flow_strings_context.dart';
import 'package:loginflow_auth/src/sign_in/model/field_error.dart';
import 'package:loginflow_auth/src/sign_in/ui/presentation/passkeys_presentation.dart';
import 'package:loginflow_auth/src/sign_in/ui/sign_in_keys.dart';
import 'package:loginflow_auth/src/sign_in/viewmodel/passkeys_viewmodel.dart';

/// Asks for a passkey's new name; pops it, or `null` when cancelled. The
/// name is checked by [PasskeysViewModel.passkeyNameError].
class PasskeyRenameDialog extends StatefulWidget {
  const PasskeyRenameDialog({
    required this.initialName,
    required this.viewModel,
    super.key,
  });

  final String? initialName;
  final PasskeysViewModel viewModel;

  @override
  State<PasskeyRenameDialog> createState() => _PasskeyRenameDialogState();
}

class _PasskeyRenameDialogState extends State<PasskeyRenameDialog> {
  late final TextEditingController _name = TextEditingController(
    text: widget.initialName,
  );
  FieldError _nameError = FieldError.none;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _save() {
    final error = widget.viewModel.passkeyNameError(_name.text);
    if (error != FieldError.none) {
      setState(() => _nameError = error);
      return;
    }
    Navigator.of(context).pop(_name.text);
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.loginFlowStrings;
    return AlertDialog(
      title: Text(strings.renamePasskey),
      content: TextField(
        key: SignInKeys.passkeyNameField,
        controller: _name,
        autofocus: true,
        textInputAction: .done,
        onSubmitted: (_) => _save(),
        decoration: InputDecoration(
          labelText: strings.passkeyNameLabel,
          errorText: _nameError.toPasskeyNameMessage(strings),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(strings.cancelButton),
        ),
        FilledButton(
          key: SignInKeys.passkeyDialogConfirm,
          onPressed: _save,
          child: Text(strings.saveButton),
        ),
      ],
    );
  }
}
