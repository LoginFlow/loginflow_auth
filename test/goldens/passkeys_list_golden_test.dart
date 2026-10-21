import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loginflow_auth/src/sign_in/model/passkeys_phase.dart';
import 'package:loginflow_auth/src/sign_in/model/passkeys_state.dart';

import 'golden_test_harness.dart';
import 'golden_variants.dart';
import 'passkeys_fixture.dart';

/// `LoginFlowPasskeys` listing the user's passkeys, with "Add a passkey".
void main() {
  const screen = 'passkeys_list';

  for (final variant in baseGoldenVariants) {
    testWidgets('$screen renders — ${variant.name}', (tester) async {
      await pumpPasskeysGolden(
        tester,
        state: PasskeysState(
          phase: PasskeysListed(passkeys: goldenPasskeys),
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
