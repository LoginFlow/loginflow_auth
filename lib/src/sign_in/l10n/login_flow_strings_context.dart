import 'package:flutter/widgets.dart';
import 'package:loginflow_auth/src/sign_in/l10n/login_flow_strings.dart';
import 'package:loginflow_auth/src/sign_in/l10n/login_flow_strings_en.dart';
import 'package:loginflow_auth/src/sign_in/l10n/login_flow_strings_es.dart';

/// Texts for the ambient locale: Spanish for `es`, English otherwise. No
/// delegate registration is needed; wrap the widget in
/// `Localizations.override` to force a language.
extension LoginFlowStringsContext on BuildContext {
  LoginFlowStrings get loginFlowStrings => switch (languageCode) {
    'es' => const LoginFlowStringsEs(),
    _ => const LoginFlowStringsEn(),
  };

  String get languageCode =>
      Localizations.maybeLocaleOf(this)?.languageCode ?? 'en';
}
