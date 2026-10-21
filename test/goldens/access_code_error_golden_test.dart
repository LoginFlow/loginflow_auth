import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loginflow_auth/src/sign_in/model/sign_in_feedback.dart';
import 'package:loginflow_auth/src/sign_in/model/sign_in_phase.dart';
import 'package:loginflow_auth/src/sign_in/model/sign_in_state.dart';

import 'golden_test_harness.dart';
import 'golden_variants.dart';

/// `AccessCodeStep` after the server refused the code: the message an
/// `InvalidAccessCode` maps to (unknown, expired, used or revoked — never
/// told apart), as the only entry screen of an access-code-only app (no
/// "Back").
void main() {
  const screen = 'access_code_error';
  const state = SignInState(
    phase: SignInAccessCodeEntry(),
    isAccessCodeOffered: true,
    feedback: SignInFeedback.invalidAccessCode,
  );

  for (final variant in baseGoldenVariants) {
    testWidgets('$screen renders — ${variant.name}', (tester) async {
      await pumpSignInGolden(
        tester,
        state: state,
        size: variant.size,
        brightness: variant.brightness,
      );

      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile(goldenPath(screen, variant.name)),
      );
    });
  }
}
