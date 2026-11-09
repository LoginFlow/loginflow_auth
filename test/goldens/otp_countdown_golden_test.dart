import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loginflow_auth/src/sign_in/model/sign_in_phase.dart';
import 'package:loginflow_auth/src/sign_in/model/sign_in_state.dart';

import 'golden_test_harness.dart';
import 'golden_variants.dart';

/// `OtpStep` right after the code was sent: "Resend code (0:42)" disabled
/// while the core's resend wait runs, with the delivery help below the
/// "code sent" line.
void main() {
  const screen = 'otp_code_countdown';
  const state = SignInState(
    phase: SignInOtpEntry(email: 'ana@example.com', resendSecondsLeft: 42),
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
