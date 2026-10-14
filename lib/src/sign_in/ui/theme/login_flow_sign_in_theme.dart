import 'dart:ui';

import 'package:flutter/material.dart';

/// Design tokens of the sign-in UI. Colors and typography come from the
/// app's `ColorScheme` and `TextTheme`; this extension holds the rest. Add
/// it to `ThemeData.extensions` to brand the UI; without it, [standard] is
/// used.
@immutable
class LoginFlowSignInTheme extends ThemeExtension<LoginFlowSignInTheme> {
  const LoginFlowSignInTheme({
    this.cardMaxWidth = 440,
    this.spacingSmall = 8,
    this.spacingMedium = 16,
    this.spacingLarge = 24,
    this.cornerRadius = 16,
    this.progressThickness = 1.5,
    this.logoHeight = 56,
    this.actionHeight = 48,
    this.cardColor,
  });

  static const LoginFlowSignInTheme standard = LoginFlowSignInTheme();

  /// Card width on tablet and desktop.
  final double cardMaxWidth;
  final double spacingSmall;
  final double spacingMedium;
  final double spacingLarge;
  final double cornerRadius;

  /// Height of the thin loading bar (1–1.5 px).
  final double progressThickness;
  final double logoHeight;

  /// Minimum height of buttons (touch target ≥ 48 dp).
  final double actionHeight;

  /// Card background; `ColorScheme.surfaceContainerLow` when null.
  final Color? cardColor;

  @override
  LoginFlowSignInTheme copyWith({
    double? cardMaxWidth,
    double? spacingSmall,
    double? spacingMedium,
    double? spacingLarge,
    double? cornerRadius,
    double? progressThickness,
    double? logoHeight,
    double? actionHeight,
    Color? cardColor,
  }) => LoginFlowSignInTheme(
    cardMaxWidth: cardMaxWidth ?? this.cardMaxWidth,
    spacingSmall: spacingSmall ?? this.spacingSmall,
    spacingMedium: spacingMedium ?? this.spacingMedium,
    spacingLarge: spacingLarge ?? this.spacingLarge,
    cornerRadius: cornerRadius ?? this.cornerRadius,
    progressThickness: progressThickness ?? this.progressThickness,
    logoHeight: logoHeight ?? this.logoHeight,
    actionHeight: actionHeight ?? this.actionHeight,
    cardColor: cardColor ?? this.cardColor,
  );

  @override
  LoginFlowSignInTheme lerp(LoginFlowSignInTheme? other, double t) {
    if (other == null) {
      return this;
    }
    return LoginFlowSignInTheme(
      cardMaxWidth:
          lerpDouble(cardMaxWidth, other.cardMaxWidth, t) ?? cardMaxWidth,
      spacingSmall:
          lerpDouble(spacingSmall, other.spacingSmall, t) ?? spacingSmall,
      spacingMedium:
          lerpDouble(spacingMedium, other.spacingMedium, t) ?? spacingMedium,
      spacingLarge:
          lerpDouble(spacingLarge, other.spacingLarge, t) ?? spacingLarge,
      cornerRadius:
          lerpDouble(cornerRadius, other.cornerRadius, t) ?? cornerRadius,
      progressThickness:
          lerpDouble(progressThickness, other.progressThickness, t) ??
          progressThickness,
      logoHeight: lerpDouble(logoHeight, other.logoHeight, t) ?? logoHeight,
      actionHeight:
          lerpDouble(actionHeight, other.actionHeight, t) ?? actionHeight,
      cardColor: Color.lerp(cardColor, other.cardColor, t),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LoginFlowSignInTheme &&
          cardMaxWidth == other.cardMaxWidth &&
          spacingSmall == other.spacingSmall &&
          spacingMedium == other.spacingMedium &&
          spacingLarge == other.spacingLarge &&
          cornerRadius == other.cornerRadius &&
          progressThickness == other.progressThickness &&
          logoHeight == other.logoHeight &&
          actionHeight == other.actionHeight &&
          cardColor == other.cardColor;

  @override
  int get hashCode => Object.hash(
    cardMaxWidth,
    spacingSmall,
    spacingMedium,
    spacingLarge,
    cornerRadius,
    progressThickness,
    logoHeight,
    actionHeight,
    cardColor,
  );
}

/// The sign-in tokens of the ambient theme.
extension LoginFlowSignInThemeContext on BuildContext {
  LoginFlowSignInTheme get signInTheme =>
      Theme.of(this).extension<LoginFlowSignInTheme>() ??
      LoginFlowSignInTheme.standard;
}
