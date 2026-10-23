import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loginflow_auth/src/sign_in/model/passkeys_phase.dart';
import 'package:loginflow_auth/src/sign_in/model/passkeys_state.dart';
import 'package:loginflow_auth/src/sign_in/model/sign_in_phase.dart';
import 'package:loginflow_auth/src/sign_in/model/sign_in_state.dart';

import 'golden_test_harness.dart';
import 'golden_variants.dart';
import 'passkeys_fixture.dart';

/// `LoginFlowPasskeys` while the server asks for a recent sign-in before
/// adding a passkey: the bundled password step (identifier locked, as for a
/// step-up) inside the manager, with "Email me a code" offered because the
/// client allows email codes.
void main() {
  const screen = 'passkeys_reauthentication';

  for (final variant in baseGoldenVariants) {
    testWidgets('$screen renders — ${variant.name}', (tester) async {
      await pumpPasskeysGolden(
        tester,
        state: PasskeysState(
          phase: PasskeysReauthenticating(passkeys: goldenPasskeys),
        ),
        size: variant.size,
        brightness: variant.brightness,
        signInState: const SignInState(
          phase: SignInPasswordEntry(
            isForgotPasswordShown: false,
            isIdentifierLocked: true,
            isEmailCodeOffered: true,
          ),
          canGoBack: true,
        ),
      );

      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile(goldenPath(screen, variant.name)),
      );
    });
  }
}
