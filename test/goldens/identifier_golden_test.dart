import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loginflow_auth/src/sign_in/model/sign_in_phase.dart';
import 'package:loginflow_auth/src/sign_in/model/sign_in_state.dart';

import 'golden_test_harness.dart';
import 'golden_variants.dart';

/// `EmailStep`: the identifier/email form, reached directly when the app
/// configures a single method and the server allows it.
void main() {
  const screen = 'identifier';
  const state = SignInState(
    phase: SignInEmailEntry(),
    isPasskeySignInOffered: true,
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

  testWidgets('$screen renders — phone_light_en', (tester) async {
    await pumpSignInGolden(
      tester,
      state: state,
      size: GoldenDeviceSize.phone,
      brightness: Brightness.light,
      locale: const Locale('en'),
    );

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile(goldenPath(screen, 'phone_light_en')),
    );
  });

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

  testWidgets('$screen renders — phone_light_legal_links', (tester) async {
    await pumpSignInGolden(
      tester,
      state: state.copyWith(
        policyUri: Uri.parse('https://acme.example/privacy'),
        tosUri: Uri.parse('https://acme.example/terms'),
      ),
      size: GoldenDeviceSize.phone,
      brightness: Brightness.light,
    );

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile(goldenPath(screen, 'phone_light_legal_links')),
    );
  });
}
