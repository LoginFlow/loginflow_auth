import 'dart:async';

import 'package:flutter/material.dart';
import 'package:loginflow_auth/src/core/protocol/passkeys/passkey_credential.dart';
import 'package:loginflow_auth/src/sign_in/l10n/login_flow_strings_context.dart';
import 'package:loginflow_auth/src/sign_in/model/passkeys_state.dart';
import 'package:loginflow_auth/src/sign_in/ui/sign_in_keys.dart';
import 'package:loginflow_auth/src/sign_in/ui/theme/login_flow_sign_in_theme.dart';
import 'package:loginflow_auth/src/sign_in/ui/widget/passkey_tile.dart';
import 'package:loginflow_auth/src/sign_in/viewmodel/passkeys_viewmodel.dart';

/// The user's passkeys, one tile each, and "Add a passkey".
class PasskeyListStep extends StatelessWidget {
  const PasskeyListStep({
    required this.passkeys,
    required this.state,
    required this.viewModel,
    this.username,
    this.displayName,
    super.key,
  });

  final List<PasskeyCredential> passkeys;
  final PasskeysState state;
  final PasskeysViewModel viewModel;
  final String? username;
  final String? displayName;

  @override
  Widget build(BuildContext context) {
    final strings = context.loginFlowStrings;
    final theme = context.signInTheme;
    return Column(
      crossAxisAlignment: .stretch,
      spacing: theme.spacingMedium,
      children: [
        if (passkeys.isEmpty)
          Semantics(liveRegion: true, child: Text(strings.passkeysEmpty)),
        ...passkeys.map(
          (passkey) => PasskeyTile(
            key: ValueKey<String>(passkey.id),
            passkey: passkey,
            isEnabled: !state.isBusy,
            viewModel: viewModel,
          ),
        ),
        FilledButton.icon(
          key: SignInKeys.passkeysAddButton,
          style: FilledButton.styleFrom(
            minimumSize: Size.fromHeight(theme.actionHeight),
          ),
          onPressed: state.isBusy
              ? null
              : () => unawaited(
                  viewModel.addPasskey(
                    username: username,
                    displayName: displayName,
                  ),
                ),
          icon: const Icon(Icons.add),
          label: Text(strings.addPasskey),
        ),
      ],
    );
  }
}
