import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loginflow_auth/src/sign_in/model/sign_in_phase.dart';
import 'package:loginflow_auth/src/sign_in/model/sign_in_state.dart';

import 'golden_test_harness.dart';
import 'golden_variants.dart';

/// `OtpStep` with `isMagicLinkOffered`: the server-driven "Email me a
/// sign-in link instead" action on top of the email-code screen
/// (`doc/server-contract.md` §5.6 `magic_link`; the protocol has no
/// separate "link sent" screen — sending the code already put the user on
/// this screen, and the magic link reuses the same inbox message).
void main() {
  const screen = 'magic_link';
  const state = SignInState(
    phase: SignInOtpEntry(email: 'ana@example.com', resendSecondsLeft: 0),
    isMagicLinkOffered: true,
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
