import 'package:flutter/widgets.dart';
import 'package:loginflow_auth/src/sign_in/l10n/login_flow_locale_service.dart';
import 'package:loginflow_auth/src/sign_in/l10n/login_flow_strings.dart';
import 'package:loginflow_auth/src/sign_in/l10n/login_flow_strings_en.dart';
import 'package:loginflow_auth/src/sign_in/l10n/login_flow_strings_es.dart';

/// Texts for the effective locale ([LoginFlowLocaleService.resolve]): an
/// explicit override, else the ambient locale, else `es`. No delegate
/// registration is needed; wrap the widget in `Localizations.override` to
/// force a language ambiently, or call
/// `LoginFlowLocaleService.setLocale(...)` to force it regardless of the
/// ambient tree.
extension LoginFlowStringsContext on BuildContext {
  LoginFlowStrings get loginFlowStrings => switch (languageCode) {
    'es' => const LoginFlowStringsEs(),
    _ => const LoginFlowStringsEn(),
  };

  String get languageCode =>
      LoginFlowLocaleService.resolve(this).languageCode;
}
