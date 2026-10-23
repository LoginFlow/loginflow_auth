import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loginflow_auth/src/sign_in/model/passkeys_phase.dart';
import 'package:loginflow_auth/src/sign_in/model/passkeys_state.dart';
import 'package:loginflow_auth/src/sign_in/ui/sign_in_keys.dart';

import 'golden_test_harness.dart';
import 'golden_variants.dart';
import 'passkeys_fixture.dart';

/// The delete confirmation of a passkey, opened from its tile.
void main() {
  const screen = 'passkeys_delete_dialog';

  for (final variant in baseGoldenVariants) {
    testWidgets('$screen renders — ${variant.name}', (tester) async {
      await pumpPasskeysGolden(
        tester,
        state: PasskeysState(phase: PasskeysListed(passkeys: goldenPasskeys)),
        size: variant.size,
        brightness: variant.brightness,
      );

      await tester.tap(
        find.byKey(
          const ValueKey<String>(
            '${SignInKeys.passkeyDeletePrefix}.credential-laptop',
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile(goldenPath(screen, variant.name)),
      );
    });
  }
}
