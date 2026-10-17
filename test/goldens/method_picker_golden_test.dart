import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loginflow_auth/src/sign_in/model/auth_method.dart';
import 'package:loginflow_auth/src/sign_in/model/sign_in_phase.dart';
import 'package:loginflow_auth/src/sign_in/model/sign_in_state.dart';

import 'golden_test_harness.dart';
import 'golden_variants.dart';

/// `MethodPickerStep`: one button per configured method, in order, plus the
/// passkey button and "Create an account" when the server offers them —
/// every provider button the sign-in flow ships (password, Google,
/// Microsoft, Apple, Facebook, email code) in one screen.
void main() {
  const screen = 'method_picker';
  const state = SignInState(
    phase: SignInChoosingMethod(
      methods: [
        PasswordMethod(),
        GoogleMethod(),
        MicrosoftMethod(),
        AppleMethod(),
        FacebookMethod(),
        EmailOtpMethod(resendCooldown: Duration.zero),
      ],
    ),
    isPasskeySignInOffered: true,
    isSignUpOffered: true,
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

  testWidgets('$screen renders — phone_light_custom_branding', (
    tester,
  ) async {
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
