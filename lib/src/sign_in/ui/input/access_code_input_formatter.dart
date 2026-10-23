import 'dart:math';

import 'package:flutter/services.dart';
import 'package:loginflow_auth/src/core/access_code/access_code_format.dart';

/// Formats a text field as an access code while the user types or pastes
/// (`AccessCodeFormat`): uppercase, only alphabet characters, at most eight,
/// with the dash inserted after the fourth. The caret stays after the last
/// character the user typed.
///
/// ```dart
/// TextField(
///   inputFormatters: const [AccessCodeInputFormatter()],
///   textCapitalization: TextCapitalization.characters,
///   autocorrect: false,
/// )
/// ```
///
/// Send the field's text through `LoginFlowAuth.signInWithAccessCode`; it
/// normalizes it again, so the dash never reaches the server.
class AccessCodeInputFormatter extends TextInputFormatter {
  /// Creates an [AccessCodeInputFormatter].
  const AccessCodeInputFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final text = newValue.text;
    final caret = newValue.selection.isValid
        ? newValue.selection.extentOffset.clamp(0, text.length)
        : text.length;
    final code = AccessCodeFormat.filter(text);
    final formatted = AccessCodeFormat.display(code);
    final codeBeforeCaret = AccessCodeFormat.filter(text.substring(0, caret))
        .length;
    final offset = codeBeforeCaret > AccessCodeFormat.groupLength
        ? codeBeforeCaret + AccessCodeFormat.separator.length
        : codeBeforeCaret;
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: min(offset, formatted.length)),
    );
  }
}
