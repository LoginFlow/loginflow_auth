import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loginflow_auth/src/sign_in/model/sign_in_phase.dart';
import 'package:loginflow_auth/src/sign_in/model/sign_in_state.dart';

import 'golden_test_harness.dart';
import 'golden_variants.dart';

/// `TemporaryAccessPassStep` (TAP): email + single-use admin-issued code,
/// `doc/server-contract.md` §5.7.
void main() {
  const screen = 'temporary_access_pass';
  const state = SignInState(
    phase: SignInTemporaryAccessPassEntry(),
    canGoBack: true,
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
