import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loginflow_auth/src/sign_in/model/sign_in_phase.dart';
import 'package:loginflow_auth/src/sign_in/model/sign_in_state.dart';

import 'golden_test_harness.dart';
import 'golden_variants.dart';

/// `SignInMessageStep` for `SignInAwaitingBrowser`: the redirect-to-web
/// notice shown while the system browser tab is open (Microsoft, SSO
/// across domains, `doc/server-contract.md` redirect_to_web).
void main() {
  const screen = 'redirect_to_web';
  const state = SignInState(phase: SignInAwaitingBrowser());

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
