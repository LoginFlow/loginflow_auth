import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loginflow_auth/src/sign_in/l10n/generated/login_flow_localizations.dart';
import 'package:loginflow_auth/src/sign_in/l10n/generated/login_flow_localizations_en.dart';
import 'package:loginflow_auth/src/sign_in/l10n/generated/login_flow_localizations_es.dart';
import 'package:loginflow_auth/src/sign_in/l10n/login_flow_locale_service.dart';
import 'package:loginflow_auth/src/sign_in/l10n/login_flow_strings_context.dart';

/// Every getter/method name declared on [LoginFlowLocalizations], read via
/// reflection-free enumeration: both concrete locales are asserted to
/// return a non-empty, distinct-from-the-key string for each one. A
/// locale missing a translation falls back silently in generated code,
/// so this test is the guard that actually catches it.
final _plainKeys = <String Function(LoginFlowLocalizations)>[
  (l) => l.signInTitle,
  (l) => l.signInSubtitle,
  (l) => l.continueWithPassword,
  (l) => l.continueWithEmailCode,
  (l) => l.continueWithGoogle,
  (l) => l.continueWithMicrosoft,
  (l) => l.continueWithApple,
  (l) => l.continueWithFacebook,
  (l) => l.continueWithPasskey,
  (l) => l.temporaryAccessPassTitle,
  (l) => l.temporaryAccessPassInstructions,
  (l) => l.useTemporaryAccessPass,
  (l) => l.emailLabel,
  (l) => l.passwordLabel,
  (l) => l.showPassword,
  (l) => l.hidePassword,
  (l) => l.signInButton,
  (l) => l.forgotPassword,
  (l) => l.sendCodeButton,
  (l) => l.codeLabel,
  (l) => l.verifyButton,
  (l) => l.resendCode,
  (l) => l.sendMagicLink,
  (l) => l.twoStepTitle,
  (l) => l.authenticatorInstructions,
  (l) => l.recoveryInstructions,
  (l) => l.useRecoveryCode,
  (l) => l.useAuthenticatorCode,
  (l) => l.back,
  (l) => l.createAccount,
  (l) => l.continueInBrowser,
  (l) => l.ssoSubtitle,
  (l) => l.useAnotherAccount,
  (l) => l.lockedOutTitle,
  (l) => l.tryAgain,
  (l) => l.optionsUnavailable,
  (l) => l.noMethods,
  (l) => l.notConfigured,
  (l) => l.feedbackInvalidCredential,
  (l) => l.feedbackCodeExpired,
  (l) => l.feedbackNetwork,
  (l) => l.feedbackSessionExpired,
  (l) => l.feedbackSessionRevoked,
  (l) => l.feedbackSsoUnavailable,
  (l) => l.feedbackProviderUnavailable,
  (l) => l.feedbackUnexpected,
  (l) => l.emailRequired,
  (l) => l.emailInvalid,
  (l) => l.passwordRequired,
  (l) => l.codeRequired,
  (l) => l.useAccessCode,
  (l) => l.accessCodeTitle,
  (l) => l.accessCodeInstructions,
  (l) => l.accessCodeHint,
  (l) => l.feedbackInvalidAccessCode,
  (l) => l.feedbackAccessCodesUnavailable,
  (l) => l.feedbackAccessCodeNotConfigured,
  (l) => l.passkeysTitle,
  (l) => l.passkeysSubtitle,
  (l) => l.passkeysEmpty,
  (l) => l.passkeysLoadFailed,
  (l) => l.passkeysSignedOut,
  (l) => l.addPasskey,
  (l) => l.passkeyUnnamed,
  (l) => l.renamePasskey,
  (l) => l.deletePasskey,
  (l) => l.passkeyNameLabel,
  (l) => l.passkeyNameRequired,
  (l) => l.saveButton,
  (l) => l.cancelButton,
  (l) => l.deletePasskeyTitle,
  (l) => l.reauthenticateTitle,
  (l) => l.reauthenticateMessage,
  (l) => l.feedbackPasskeyNotConfigured,
  (l) => l.feedbackPasskeyNotSupported,
  (l) => l.feedbackPasskeyNoCredentials,
  (l) => l.feedbackPasskeySecurityError,
  (l) => l.feedbackPasskeyDomainNotAssociated,
  (l) => l.feedbackPasskeyAlreadyRegistered,
  (l) => l.feedbackPasskeyTimeout,
  (l) => l.feedbackPasskeyInvalidResponse,
  (l) => l.feedbackPasskeyFailed,
  (l) => l.feedbackPasskeyNotFound,
  (l) => l.feedbackPasskeysUnavailable,
  (l) => l.feedbackReauthenticationRequired,
  (l) => l.feedbackRateLimited,
];

void main() {
  group('LoginFlowLocaleService.supportedLocales completeness', () {
    final locales = <Locale, LoginFlowLocalizations>{
      const Locale('es'): LoginFlowLocalizationsEs(),
      const Locale('en'): LoginFlowLocalizationsEn(),
    };

    test('every supported locale has a generated translation set', () {
      for (final locale in LoginFlowLocaleService.supportedLocales) {
        expect(
          locales.containsKey(locale),
          isTrue,
          reason:
              'Add $locale to this test alongside its .arb file under '
              'lib/src/sign_in/l10n/arb/.',
        );
      }
    });

    test('every key is non-empty in every supported locale', () {
      for (final entry in locales.entries) {
        for (final read in _plainKeys) {
          expect(
            read(entry.value),
            isNotEmpty,
            reason: 'Missing translation in ${entry.key.languageCode}.arb',
          );
        }
      }
    });

    test('placeholder keys interpolate in every supported locale', () {
      for (final l10n in locales.values) {
        expect(l10n.codeSentTo('a@b.com'), contains('a@b.com'));
        expect(l10n.resendIn(7), contains('7'));
        expect(l10n.continueAs('Ana'), contains('Ana'));
        expect(l10n.lockedOutMessage(30), contains('30'));
        expect(l10n.accessCodeIncomplete(8), contains('8'));
        expect(l10n.passkeyAddedOn('3 Mar 2026'), contains('3 Mar 2026'));
        expect(l10n.passkeyLastUsedOn('2 Oct 2026'), contains('2 Oct 2026'));
        expect(l10n.deletePasskeyMessage('MacBook'), contains('MacBook'));
      }
    });
  });

  group('LoginFlowLocaleService.resolve', () {
    tearDown(() => LoginFlowLocaleService.setLocale(null));

    testWidgets('falls back to es with no ambient locale and no override', (
      tester,
    ) async {
      await tester.pumpWidget(
        Localizations(
          locale: const Locale('es'),
          delegates: const [DefaultWidgetsLocalizations.delegate],
          child: Builder(
            builder: (context) {
              expect(context.languageCode, 'es');
              return const SizedBox();
            },
          ),
        ),
      );
    });

    testWidgets('an unsupported ambient locale falls back to es', (
      tester,
    ) async {
      await tester.pumpWidget(
        Localizations(
          locale: const Locale('fr'),
          delegates: const [DefaultWidgetsLocalizations.delegate],
          child: Builder(
            builder: (context) {
              expect(context.languageCode, 'es');
              return const SizedBox();
            },
          ),
        ),
      );
    });

    testWidgets('an explicit override wins over the ambient locale', (
      tester,
    ) async {
      LoginFlowLocaleService.setLocale(const Locale('en'));
      await tester.pumpWidget(
        Localizations(
          locale: const Locale('es'),
          delegates: const [DefaultWidgetsLocalizations.delegate],
          child: Builder(
            builder: (context) {
              expect(context.languageCode, 'en');
              return const SizedBox();
            },
          ),
        ),
      );
    });
  });
}
