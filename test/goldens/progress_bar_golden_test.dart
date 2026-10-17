import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loginflow_auth/src/sign_in/model/sign_in_phase.dart';
import 'package:loginflow_auth/src/sign_in/model/sign_in_state.dart';

import 'golden_test_harness.dart';
import 'golden_variants.dart';

/// `SignInProgressBar` with `isBusy: true`, over the password step. The
/// test binding never advances a pumped duration (`pumpSignInGolden` calls
/// `tester.pump()` with none), so the indeterminate
/// `LinearProgressIndicator` always renders at animation frame zero —
/// deterministic across machines and runs.
void main() {
  const screen = 'progress_bar_busy';
  const state = SignInState(
    phase: SignInPasswordEntry(isForgotPasswordShown: true),
    isBusy: true,
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
