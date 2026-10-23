import 'package:flutter/widgets.dart';
import 'package:loginflow_auth/src/sign_in/l10n/generated/login_flow_localizations.dart';
import 'package:reactive_notifier/reactive_notifier.dart';

/// Resolves which locale the built-in sign-in UI renders in.
///
/// Resolution order: an explicit override set by the host app via
/// [setLocale] wins over everything; otherwise the ambient
/// [Localizations] locale of the widget tree is used; if neither yields a
/// supported locale, it falls back to `es` (the library's base locale).
///
/// Widgets never branch on a locale themselves — they read
/// `context.loginFlowStrings`, and this is the only place that decides
/// which translation set that resolves to.
mixin LoginFlowLocaleService {
  /// The explicit locale override; `null` follows the app's [Localizations].
  static final instance = ReactiveNotifier<Locale?>(() => null);

  /// Locales the library ships translations for today. Adding a new one
  /// is just adding its `.arb` file under `lib/src/sign_in/l10n/arb/` and
  /// listing it here — no widget changes.
  static const supportedLocales = [Locale('es'), Locale('en')];

  static const _fallback = Locale('es');

  /// Forces the built-in UI to a given language, regardless of the
  /// device or the ambient [Localizations]. Pass `null` to go back to
  /// following the ambient/device locale.
  static void setLocale(Locale? locale) => instance.updateState(locale);

  /// The effective locale for [context]: the explicit override, else the
  /// ambient locale, else [_fallback].
  static Locale resolve(BuildContext context) {
    final override = instance.notifier;
    if (override != null && _isSupported(override)) {
      return override;
    }
    final ambient = Localizations.maybeLocaleOf(context);
    if (ambient != null && _isSupported(ambient)) {
      return ambient;
    }
    return _fallback;
  }

  static bool _isSupported(Locale locale) =>
      supportedLocales.any((l) => l.languageCode == locale.languageCode);

  /// The generated translation set for [resolve]'s result.
  static LoginFlowLocalizations lookup(BuildContext context) =>
      lookupLoginFlowLocalizations(resolve(context));
}
