import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loginflow_auth/src/sign_in/model/sign_in_phase.dart';
import 'package:loginflow_auth/src/sign_in/model/sign_in_state.dart';

import 'golden_test_harness.dart';
import 'golden_variants.dart';

/// `PasswordStep`: email + password form with "Forgot password", the
/// passkey button and "Use a temporary access pass" all offered.
void main() {
  const screen = 'password';
  const state = SignInState(
    phase: SignInPasswordEntry(isForgotPasswordShown: true),
    isPasskeySignInOffered: true,
    isTemporaryAccessPassOffered: true,
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

  testWidgets('$screen renders — phone_light_custom_branding', (tester) async {
    await pumpSignInGolden(
      tester,
      state: state,
      size: GoldenDeviceSize.phone,
      brightness: Brightness.light,
      theme: customBrandingTheme,
      logo: customBrandLogo,
    );

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile(goldenPath(screen, 'phone_light_custom_branding')),
    );
  });
}
