import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loginflow_auth/src/sign_in/model/auth_method.dart';
import 'package:loginflow_auth/src/sign_in/model/sign_in_feedback.dart';
import 'package:loginflow_auth/src/sign_in/model/sign_in_phase.dart';
import 'package:loginflow_auth/src/sign_in/model/sign_in_state.dart';

import 'golden_test_harness.dart';
import 'golden_variants.dart';

/// Two widget-visible states of the passkey affordance. The OS/platform
/// authenticator sheet itself (Credential Manager, AuthenticationServices)
/// is native chrome this library never draws, so there is nothing of ours
/// to golden while it is open — these are the two states the library's own
/// UI shows around it:
///
///  - `prompt`: the "Continue with a passkey" button on the method picker,
///    the trigger shown before the ceremony starts.
///  - `failure`: the same screen with the feedback banner a
///    `PasskeyFailed` maps to (`sign_in_feedback_mapping.dart`;
///    `notConfigured`/`notSupported`/`noCredentialsAvailable` →
///    `providerUnavailable`).
void main() {
  group('passkey_prompt', () {
    const screen = 'passkey_prompt';
    const state = SignInState(
      phase: SignInChoosingMethod(methods: [PasswordMethod()]),
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
  });

  group('passkey_failure', () {
    const screen = 'passkey_failure';
    const state = SignInState(
      phase: SignInChoosingMethod(methods: [PasswordMethod()]),
      isPasskeySignInOffered: true,
      feedback: SignInFeedback.providerUnavailable,
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
  });
}
