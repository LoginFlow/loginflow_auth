import 'dart:async';

import 'package:flutter/material.dart';
import 'package:loginflow_auth/src/sign_in/l10n/login_flow_strings_context.dart';
import 'package:loginflow_auth/src/sign_in/model/sign_in_state.dart';
import 'package:loginflow_auth/src/sign_in/ui/input/access_code_input_formatter.dart';
import 'package:loginflow_auth/src/sign_in/ui/presentation/sign_in_presentation.dart';
import 'package:loginflow_auth/src/sign_in/ui/sign_in_keys.dart';
import 'package:loginflow_auth/src/sign_in/ui/theme/login_flow_sign_in_theme.dart';
import 'package:loginflow_auth/src/sign_in/ui/widget/sign_in_buttons.dart';
import 'package:loginflow_auth/src/sign_in/viewmodel/sign_in_viewmodel.dart';

/// Access-code entry (`XXXX-XXXX`): a single-use code the tenant's backend
/// issued, reached through [SignInViewModel.useAccessCode] or shown as the
/// entry screen when it is the app's only way in. The field only shapes
/// what is typed ([AccessCodeInputFormatter]); the ViewModel validates it.
class AccessCodeStep extends StatefulWidget {
  const AccessCodeStep({
    required this.state,
    required this.viewModel,
    super.key,
  });

  final SignInState state;
  final SignInViewModel viewModel;

  @override
  State<AccessCodeStep> createState() => _AccessCodeStepState();
}

class _AccessCodeStepState extends State<AccessCodeStep> {
  final TextEditingController _code = TextEditingController();

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  void _submit() => unawaited(widget.viewModel.submitAccessCode(_code.text));

  @override
  Widget build(BuildContext context) {
    final strings = context.loginFlowStrings;
    final state = widget.state;
    final isEnabled = !state.isBusy;
    return Column(
      crossAxisAlignment: .stretch,
      spacing: context.signInTheme.spacingMedium,
      children: [
        Semantics(
          header: true,
          child: Text(
            strings.accessCodeTitle,
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        Text(strings.accessCodeInstructions),
        TextField(
          key: SignInKeys.accessCodeField,
          controller: _code,
          enabled: isEnabled,
          keyboardType: .visiblePassword,
          textInputAction: .done,
          textCapitalization: .characters,
          autocorrect: false,
          enableSuggestions: false,
          inputFormatters: const [AccessCodeInputFormatter()],
          onSubmitted: (_) => _submit(),
          decoration: InputDecoration(
            labelText: strings.accessCodeTitle,
            hintText: strings.accessCodeHint,
            errorText: state.codeError.toCodeMessage(strings),
          ),
        ),
        SignInPrimaryButton(
          label: strings.signInButton,
          onPressed: isEnabled ? _submit : null,
        ),
        if (state.canGoBack)
          SignInTextAction(
            label: strings.back,
            onPressed: isEnabled
                ? () => unawaited(widget.viewModel.goBack())
                : null,
          ),
      ],
    );
  }
}
