// TEST_CHARTER
// Requirement: a text field with `AccessCodeInputFormatter` shows what the
// user types or pastes as an access code: uppercase, only alphabet
// characters, at most 8, with the dash inserted (`doc/server-contract.md`
// §16), and the caret stays where the user was typing.
// Oracle: the `TextEditingValue` (text and selection) the formatter returns.
// Risk edge: a paste with spaces/dashes/look-alikes, typing in the middle,
// and exactly four characters (a trailing dash would make backspace stick).
// Layer: unit over Flutter's `TextInputFormatter` contract.
// Counterfactual: a formatter that returns `newValue` unchanged fails every
// case below.

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loginflow_auth/loginflow_auth.dart';

TextEditingValue _format(String text, {int? caret}) =>
    const AccessCodeInputFormatter().formatEditUpdate(
      TextEditingValue.empty,
      TextEditingValue(
        text: text,
        selection: TextSelection.collapsed(offset: caret ?? text.length),
      ),
    );

void main() {
  group('AccessCodeInputFormatter', () {
    test('uppercases and inserts the dash while typing', () {
      final value = _format('k7m2q');

      expect(value.text, 'K7M2-Q');
      expect(value.selection, const TextSelection.collapsed(offset: 6));
    });

    test('a pasted code with spaces and dashes becomes XXXX-XXXX', () {
      final value = _format('k7m2 - q9px');

      expect(value.text, 'K7M2-Q9PX');
      expect(value.selection, const TextSelection.collapsed(offset: 9));
    });

    test('look-alike and foreign characters are dropped', () {
      expect(_format('K7O1IL!').text, 'K7');
    });

    test('never grows past 8 code characters', () {
      expect(_format('K7M2Q9PXZZ').text, 'K7M2-Q9PX');
    });

    test('four characters show no trailing dash', () {
      expect(_format('k7m2').text, 'K7M2');
    });

    test('typing in the middle keeps the caret after the typed character', () {
      final value = _format('K7AM2-Q9PX', caret: 3);

      expect(value.text, 'K7AM-2Q9P');
      expect(value.selection, const TextSelection.collapsed(offset: 3));
    });
  });
}
