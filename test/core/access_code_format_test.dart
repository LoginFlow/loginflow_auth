// TEST_CHARTER
// Requirement: every app shares ONE definition of an access code
// (`doc/server-contract.md` §16): 8 characters from
// 23456789ABCDEFGHJKMNPQRSTUVWXYZ (no 0 O 1 I L), case-insensitive, spaces
// and dashes ignored, displayed XXXX-XXXX.
// Oracle: the strings `AccessCodeFormat` returns for real user input.
// Risk edge: look-alike characters (0 O 1 I L) and partial input — a code
// the server can never have issued must not count as complete.
// Layer: pure Dart unit (no I/O involved).
// Counterfactual: an identity `normalize`/`display` or an always-true
// `isComplete` fails these expectations.

import 'package:flutter_test/flutter_test.dart';
import 'package:loginflow_auth/loginflow_auth_core.dart';

void main() {
  group('AccessCodeFormat', () {
    test('the alphabet has no look-alike characters', () {
      expect(AccessCodeFormat.alphabet, hasLength(31));
      for (final excluded in <String>['0', 'O', '1', 'I', 'L']) {
        expect(AccessCodeFormat.alphabet, isNot(contains(excluded)));
      }
    });

    test('normalize uppercases and ignores spaces and dashes', () {
      expect(AccessCodeFormat.normalize(' k7m2-q9 px '), 'K7M2Q9PX');
    });

    test('filter keeps only alphabet characters, at most 8', () {
      expect(AccessCodeFormat.filter('k7-m2 0o1il q9px!'), 'K7M2Q9PX');
      expect(AccessCodeFormat.filter('23456789AB'), '23456789');
    });

    test('isComplete accepts exactly 8 alphabet characters', () {
      expect(AccessCodeFormat.isComplete('k7m2-q9px'), isTrue);
      expect(AccessCodeFormat.isComplete('K7M2 Q9PX'), isTrue);
      expect(AccessCodeFormat.isComplete('K7M2Q9P'), isFalse);
      expect(AccessCodeFormat.isComplete('K7M2Q9PXZ'), isFalse);
      for (final lookAlike in <String>['0', 'O', '1', 'I', 'L']) {
        expect(AccessCodeFormat.isComplete('K7M2Q9P$lookAlike'), isFalse);
      }
    });

    test('display groups the code as XXXX-XXXX, partial input too', () {
      expect(AccessCodeFormat.display('k7m2q9px'), 'K7M2-Q9PX');
      expect(AccessCodeFormat.display('K7M'), 'K7M');
      expect(AccessCodeFormat.display('K7M2'), 'K7M2');
      expect(AccessCodeFormat.display('k7m2q'), 'K7M2-Q');
    });
  });
}
