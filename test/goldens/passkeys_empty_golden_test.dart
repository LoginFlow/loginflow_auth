import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loginflow_auth/src/sign_in/model/passkeys_phase.dart';
import 'package:loginflow_auth/src/sign_in/model/passkeys_state.dart';

import 'golden_test_harness.dart';
import 'golden_variants.dart';

/// `LoginFlowPasskeys` for a user with no passkey yet.
void main() {
  const screen = 'passkeys_empty';

  for (final variant in baseGoldenVariants) {
    testWidgets('$screen renders — ${variant.name}', (tester) async {
      await pumpPasskeysGolden(
        tester,
        state: const PasskeysState(
          phase: PasskeysListed(passkeys: []),
          isEnrollmentOffered: true,
        ),
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
