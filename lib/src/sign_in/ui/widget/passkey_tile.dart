import 'dart:async';

import 'package:flutter/material.dart';
import 'package:loginflow_auth/src/core/protocol/passkeys/passkey_credential.dart';
import 'package:loginflow_auth/src/sign_in/l10n/login_flow_strings_context.dart';
import 'package:loginflow_auth/src/sign_in/ui/presentation/passkeys_presentation.dart';
import 'package:loginflow_auth/src/sign_in/ui/theme/login_flow_sign_in_theme.dart';
import 'package:loginflow_auth/src/sign_in/ui/widget/passkey_delete_dialog.dart';
import 'package:loginflow_auth/src/sign_in/ui/widget/passkey_rename_dialog.dart';
import 'package:loginflow_auth/src/sign_in/viewmodel/passkeys_viewmodel.dart';

/// One enrolled passkey: its name, when it was added and last used, and
/// the rename and delete actions (delete behind a confirmation).
class PasskeyTile extends StatelessWidget {
  const PasskeyTile({
    required this.passkey,
    required this.isEnabled,
    required this.viewModel,
    super.key,
  });

  final PasskeyCredential passkey;
  final bool isEnabled;
  final PasskeysViewModel viewModel;

  Future<void> _rename(BuildContext context) async {
    final name = await showDialog<String>(
      context: context,
      builder: (_) =>
          PasskeyRenameDialog(initialName: passkey.name, viewModel: viewModel),
    );
    if (name != null) {
      await viewModel.renamePasskey(id: passkey.id, name: name);
    }
  }

  Future<void> _delete(BuildContext context) async {
    final isConfirmed = await showDialog<bool>(
      context: context,
      builder: (_) => PasskeyDeleteDialog(
        name: passkey.toDisplayName(context.loginFlowStrings),
      ),
    );
    if (isConfirmed == true) {
      await viewModel.deletePasskey(passkey.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.loginFlowStrings;
    final theme = context.signInTheme;
    return Material(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(theme.cornerRadius),
      clipBehavior: .antiAlias,
      child: ListTile(
        minTileHeight: theme.actionHeight,
        leading: const Icon(Icons.key_outlined),
        title: Text(passkey.toDisplayName(strings)),
        subtitle: Text(
          passkey.toDetails(strings, MaterialLocalizations.of(context)),
        ),
        trailing: Row(
          mainAxisSize: .min,
          children: [
            IconButton(
              key: passkey.toRenameKey(),
              tooltip: strings.renamePasskey,
              icon: const Icon(Icons.edit_outlined),
              onPressed: isEnabled ? () => unawaited(_rename(context)) : null,
            ),
            IconButton(
              key: passkey.toDeleteKey(),
              tooltip: strings.deletePasskey,
              icon: const Icon(Icons.delete_outline),
              onPressed: isEnabled ? () => unawaited(_delete(context)) : null,
            ),
          ],
        ),
      ),
    );
  }
}
