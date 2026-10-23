import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loginflow_auth/loginflow_auth.dart';
import 'package:loginflow_auth/src/sign_in/model/passkeys_state.dart';
import 'package:loginflow_auth/src/sign_in/model/sign_in_state.dart';
import 'package:loginflow_auth/src/sign_in/service/passkeys_service.dart';
import 'package:loginflow_auth/src/sign_in/service/sign_in_service.dart';

/// The two window sizes every golden renders at, picked so
/// `DeviceType.fromSize` (shortest side) lands on `mobile` and `desktop`
/// respectively — `loginflow_auth` treats tablet and desktop as the same
/// centered-card layout (`LoginFlowSignIn.build`), so "tablet" here uses a
/// tablet-shaped window (shortest side in the tablet band) to golden the
/// actual breakpoint band asked for, not a desktop-shaped one.
abstract final class GoldenDeviceSize {
  /// Shortest side 390 — inside the mobile band.
  static const Size phone = Size(390, 844);

  /// Shortest side 700 — inside the tablet band (600–899).
  static const Size tablet = Size(700, 1000);
}

/// A brand away from the default: different seed color, corner radius,
/// spacing and card width, so a branding regression is visible in the
/// golden image, not just in a unit test of `LoginFlowSignInTheme`.
const LoginFlowSignInTheme customBrandingTheme = LoginFlowSignInTheme(
  cardMaxWidth: 360,
  spacingSmall: 12,
  spacingMedium: 20,
  spacingLarge: 32,
  cornerRadius: 4,
  progressThickness: 3,
  logoHeight: 72,
  actionHeight: 56,
  cardColor: Color(0xFFFFF3E0),
);

/// Pumps the public [LoginFlowSignIn] widget with [state] forced on the
/// flow `ViewModel`, skipping the network entirely: goldens render pixels,
/// they do not exercise the authorization-challenge flow (that is
/// `sign_in_widget_test.dart`'s job).
///
/// Deterministic by construction: fixed window size, `devicePixelRatio: 1`,
/// `TextScaler.noScaling`, a fixed locale, and no animation is ever pumped
/// past frame zero (`tester.pump()` with no duration), so a
/// `LinearProgressIndicator`'s indeterminate animation always renders at
/// its initial, reproducible phase.
Future<void> pumpSignInGolden(
  WidgetTester tester, {
  required SignInState state,
  required Size size,
  required Brightness brightness,
  Locale locale = const Locale('es'),
  LoginFlowSignInTheme theme = LoginFlowSignInTheme.standard,
  Widget? logo,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  LoginFlowLocaleService.setLocale(locale);
  addTearDown(() => LoginFlowLocaleService.setLocale(null));

  final colorScheme = ColorScheme.fromSeed(
    seedColor: const Color(0xFF3F51B5),
    brightness: brightness,
  );
  await tester.pumpWidget(
    MediaQuery(
      data: MediaQueryData(
        size: size,
        textScaler: TextScaler.noScaling,
        platformBrightness: brightness,
      ),
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        locale: locale,
        supportedLocales: const [Locale('en'), Locale('es')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        theme: ThemeData(colorScheme: colorScheme, extensions: [theme]),
        home: LoginFlowSignIn(onSignedIn: (_) {}, logo: logo),
      ),
    ),
  );
  // `ViewModel.init()` runs when the first consumer widget mounts and
  // would overwrite an `updateState` issued before `pumpWidget` with its
  // own fresh state — the state is forced only once the flow ViewModel
  // already exists and is mounted, then a second pump renders it.
  SignInService.flow.notifier.updateState(state);
  await tester.pump();
}

/// Pumps the public [LoginFlowPasskeys] widget with [state] forced on the
/// manager `ViewModel` — same rules as [pumpSignInGolden]: no network, the
/// state is forced once the ViewModel is mounted (its `init()` would
/// overwrite an earlier one), fixed size, locale and text scale.
///
/// [signInState] is forced on the sign-in flow `ViewModel` too, for the
/// re-authentication step that renders the sign-in steps inside the
/// manager; that ViewModel mounts with the step, so it is forced after one
/// more pump.
Future<void> pumpPasskeysGolden(
  WidgetTester tester, {
  required PasskeysState state,
  required Size size,
  required Brightness brightness,
  SignInState? signInState,
  Locale locale = const Locale('es'),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  LoginFlowLocaleService.setLocale(locale);
  addTearDown(() => LoginFlowLocaleService.setLocale(null));

  await tester.pumpWidget(
    MediaQuery(
      data: MediaQueryData(
        size: size,
        textScaler: TextScaler.noScaling,
        platformBrightness: brightness,
      ),
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        locale: locale,
        supportedLocales: const [Locale('en'), Locale('es')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF3F51B5),
            brightness: brightness,
          ),
          extensions: const [LoginFlowSignInTheme.standard],
        ),
        home: const LoginFlowPasskeys(),
      ),
    ),
  );
  PasskeysService.manager.notifier.updateState(state);
  await tester.pump();
  if (signInState != null) {
    SignInService.flow.notifier.updateState(signInState);
    await tester.pump();
  }
}

/// A small brand mark for the custom-branding goldens: a host app passes
/// any `Widget`, never an asset path the library owns (`doc/decisions.md`
/// D24) — a `ColoredBox` stands in for a real logo image here so the
/// golden has no dependency on an asset file.
const Widget customBrandLogo = ColoredBox(
  color: Color(0xFFFF7043),
  child: SizedBox(width: 72, height: 72),
);

/// The golden file path for a given screen/variant combination, kept in one
/// place so every test file names its files the same way
/// (`test/goldens/README.md` documents the convention). Resolved by
/// `matchesGoldenFile` relative to this directory (`test/goldens/`), so the
/// image lands at `test/goldens/<screen>/<variant>.png`.
String goldenPath(String screen, String variant) => '$screen/$variant.png';
