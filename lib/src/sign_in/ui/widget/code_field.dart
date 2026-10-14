import 'package:flutter/material.dart';
import 'package:loginflow_auth/src/sign_in/ui/sign_in_keys.dart';

/// A one-time code field (email OTP, TOTP, recovery code) with the
/// `oneTimeCode` autofill hint so the platform can offer the received code.
class CodeField extends StatelessWidget {
  const CodeField({
    required this.controller,
    required this.label,
    required this.isEnabled,
    required this.isNumeric,
    required this.onSubmitted,
    this.errorText,
    super.key,
  });

  final TextEditingController controller;
  final String label;
  final bool isEnabled;
  final bool isNumeric;
  final VoidCallback onSubmitted;
  final String? errorText;

  @override
  Widget build(BuildContext context) => TextField(
    key: SignInKeys.codeField,
    controller: controller,
    enabled: isEnabled,
    keyboardType: isNumeric ? .number : .text,
    textInputAction: .done,
    autofillHints: const [AutofillHints.oneTimeCode],
    onSubmitted: (_) => onSubmitted(),
    decoration: InputDecoration(labelText: label, errorText: errorText),
  );
}
