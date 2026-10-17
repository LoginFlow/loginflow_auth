import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loginflow_auth/src/sign_in/model/sign_in_feedback.dart';
import 'package:loginflow_auth/src/sign_in/model/sign_in_phase.dart';
import 'package:loginflow_auth/src/sign_in/model/sign_in_state.dart';

import 'golden_test_harness.dart';
import 'golden_variants.dart';

/// `SignInFeedbackBanner` with `SignInFeedback.unexpected` over the
/// password step: the generic "something went wrong" error every
/// unmapped `LoginFlowError` falls back to (`sign_in_feedback_mapping.dart`
/// `LoginFlowErrorFeedback.toFeedback`).
void main() {
  const screen = 'error_generic';
  const state = SignInState(
    phase: SignInPasswordEntry(isForgotPasswordShown: true),
    feedback: SignInFeedback.unexpected,
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
