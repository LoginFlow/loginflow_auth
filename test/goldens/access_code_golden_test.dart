import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loginflow_auth/src/sign_in/model/sign_in_phase.dart';
import 'package:loginflow_auth/src/sign_in/model/sign_in_state.dart';

import 'golden_test_harness.dart';
import 'golden_variants.dart';

/// `AccessCodeStep`: the single-use code a tenant backend issued
/// (`XXXX-XXXX`), reached from "I have an access code" on the entry screen
/// (`doc/server-contract.md` §16).
void main() {
  const screen = 'access_code';
  const state = SignInState(
    phase: SignInAccessCodeEntry(),
    canGoBack: true,
    isAccessCodeOffered: true,
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
