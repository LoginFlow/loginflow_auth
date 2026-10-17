import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'login_flow_localizations_en.dart';
import 'login_flow_localizations_es.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of LoginFlowLocalizations
/// returned by `LoginFlowLocalizations.of(context)`.
///
/// Applications need to include `LoginFlowLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/login_flow_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: LoginFlowLocalizations.localizationsDelegates,
///   supportedLocales: LoginFlowLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the LoginFlowLocalizations.supportedLocales
/// property.
abstract class LoginFlowLocalizations {
  LoginFlowLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static LoginFlowLocalizations of(BuildContext context) {
    return Localizations.of<LoginFlowLocalizations>(
      context,
      LoginFlowLocalizations,
    )!;
  }

  static const LocalizationsDelegate<LoginFlowLocalizations> delegate =
      _LoginFlowLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('es'),
  ];

  /// Title of the entry screen.
  ///
  /// In es, this message translates to:
  /// **'Iniciar sesión'**
  String get signInTitle;

  /// No description provided for @signInSubtitle.
  ///
  /// In es, this message translates to:
  /// **'Elige cómo quieres continuar'**
  String get signInSubtitle;

  /// No description provided for @continueWithPassword.
  ///
  /// In es, this message translates to:
  /// **'Continuar con contraseña'**
  String get continueWithPassword;

  /// No description provided for @continueWithEmailCode.
  ///
  /// In es, this message translates to:
  /// **'Enviarme un código por correo'**
  String get continueWithEmailCode;

  /// No description provided for @continueWithGoogle.
  ///
  /// In es, this message translates to:
  /// **'Continuar con Google'**
  String get continueWithGoogle;

  /// No description provided for @continueWithMicrosoft.
  ///
  /// In es, this message translates to:
  /// **'Continuar con Microsoft'**
  String get continueWithMicrosoft;

  /// No description provided for @continueWithApple.
  ///
  /// In es, this message translates to:
  /// **'Continuar con Apple'**
  String get continueWithApple;

  /// No description provided for @continueWithFacebook.
  ///
  /// In es, this message translates to:
  /// **'Continuar con Facebook'**
  String get continueWithFacebook;

  /// No description provided for @continueWithPasskey.
  ///
  /// In es, this message translates to:
  /// **'Continuar con una llave de acceso'**
  String get continueWithPasskey;

  /// No description provided for @temporaryAccessPassTitle.
  ///
  /// In es, this message translates to:
  /// **'Código temporal de acceso'**
  String get temporaryAccessPassTitle;

  /// No description provided for @temporaryAccessPassInstructions.
  ///
  /// In es, this message translates to:
  /// **'Ingresa el código temporal de acceso que te dio tu administrador.'**
  String get temporaryAccessPassInstructions;

  /// No description provided for @useTemporaryAccessPass.
  ///
  /// In es, this message translates to:
  /// **'Usar un código temporal de acceso'**
  String get useTemporaryAccessPass;

  /// No description provided for @emailLabel.
  ///
  /// In es, this message translates to:
  /// **'Correo electrónico'**
  String get emailLabel;

  /// No description provided for @passwordLabel.
  ///
  /// In es, this message translates to:
  /// **'Contraseña'**
  String get passwordLabel;

  /// No description provided for @showPassword.
  ///
  /// In es, this message translates to:
  /// **'Mostrar contraseña'**
  String get showPassword;

  /// No description provided for @hidePassword.
  ///
  /// In es, this message translates to:
  /// **'Ocultar contraseña'**
  String get hidePassword;

  /// No description provided for @signInButton.
  ///
  /// In es, this message translates to:
  /// **'Iniciar sesión'**
  String get signInButton;

  /// No description provided for @forgotPassword.
  ///
  /// In es, this message translates to:
  /// **'¿Olvidaste tu contraseña?'**
  String get forgotPassword;

  /// No description provided for @sendCodeButton.
  ///
  /// In es, this message translates to:
  /// **'Enviar código'**
  String get sendCodeButton;

  /// No description provided for @codeLabel.
  ///
  /// In es, this message translates to:
  /// **'Código'**
  String get codeLabel;

  /// Confirms the code was sent to this email.
  ///
  /// In es, this message translates to:
  /// **'Enviamos un código a {email}'**
  String codeSentTo(String email);

  /// No description provided for @verifyButton.
  ///
  /// In es, this message translates to:
  /// **'Verificar'**
  String get verifyButton;

  /// No description provided for @resendCode.
  ///
  /// In es, this message translates to:
  /// **'Reenviar código'**
  String get resendCode;

  /// Countdown before the resend button is enabled again.
  ///
  /// In es, this message translates to:
  /// **'Reenviar código en {seconds} s'**
  String resendIn(int seconds);

  /// No description provided for @sendMagicLink.
  ///
  /// In es, this message translates to:
  /// **'Enviarme un enlace de inicio de sesión'**
  String get sendMagicLink;

  /// No description provided for @twoStepTitle.
  ///
  /// In es, this message translates to:
  /// **'Verificación en dos pasos'**
  String get twoStepTitle;

  /// No description provided for @authenticatorInstructions.
  ///
  /// In es, this message translates to:
  /// **'Ingresa el código de 6 dígitos de tu app de autenticación.'**
  String get authenticatorInstructions;

  /// No description provided for @recoveryInstructions.
  ///
  /// In es, this message translates to:
  /// **'Ingresa uno de tus códigos de recuperación.'**
  String get recoveryInstructions;

  /// No description provided for @useRecoveryCode.
  ///
  /// In es, this message translates to:
  /// **'Usar un código de recuperación'**
  String get useRecoveryCode;

  /// No description provided for @useAuthenticatorCode.
  ///
  /// In es, this message translates to:
  /// **'Usar tu app de autenticación'**
  String get useAuthenticatorCode;

  /// No description provided for @back.
  ///
  /// In es, this message translates to:
  /// **'Volver'**
  String get back;

  /// No description provided for @createAccount.
  ///
  /// In es, this message translates to:
  /// **'Crear una cuenta'**
  String get createAccount;

  /// No description provided for @continueInBrowser.
  ///
  /// In es, this message translates to:
  /// **'Continúa en tu navegador…'**
  String get continueInBrowser;

  /// SSO confirmation: continue as the already signed-in account.
  ///
  /// In es, this message translates to:
  /// **'Continuar como {name}'**
  String continueAs(String name);

  /// No description provided for @ssoSubtitle.
  ///
  /// In es, this message translates to:
  /// **'Ya iniciaste sesión en otra app de este dispositivo.'**
  String get ssoSubtitle;

  /// No description provided for @useAnotherAccount.
  ///
  /// In es, this message translates to:
  /// **'Usar otra cuenta'**
  String get useAnotherAccount;

  /// No description provided for @lockedOutTitle.
  ///
  /// In es, this message translates to:
  /// **'Demasiados intentos'**
  String get lockedOutTitle;

  /// Lockout countdown after too many failed attempts.
  ///
  /// In es, this message translates to:
  /// **'Vuelve a intentarlo en {seconds} segundos.'**
  String lockedOutMessage(int seconds);

  /// No description provided for @tryAgain.
  ///
  /// In es, this message translates to:
  /// **'Reintentar'**
  String get tryAgain;

  /// No description provided for @optionsUnavailable.
  ///
  /// In es, this message translates to:
  /// **'No se pudieron cargar las opciones de inicio de sesión.'**
  String get optionsUnavailable;

  /// No description provided for @noMethods.
  ///
  /// In es, this message translates to:
  /// **'No hay métodos de inicio de sesión disponibles para esta app.'**
  String get noMethods;

  /// No description provided for @notConfigured.
  ///
  /// In es, this message translates to:
  /// **'El inicio de sesión no está configurado.'**
  String get notConfigured;

  /// No description provided for @feedbackInvalidCredential.
  ///
  /// In es, this message translates to:
  /// **'Los datos que ingresaste no son correctos.'**
  String get feedbackInvalidCredential;

  /// No description provided for @feedbackCodeExpired.
  ///
  /// In es, this message translates to:
  /// **'El código venció. Solicita uno nuevo.'**
  String get feedbackCodeExpired;

  /// No description provided for @feedbackNetwork.
  ///
  /// In es, this message translates to:
  /// **'Revisa tu conexión e inténtalo de nuevo.'**
  String get feedbackNetwork;

  /// No description provided for @feedbackSessionExpired.
  ///
  /// In es, this message translates to:
  /// **'El inicio de sesión tardó demasiado. Empieza de nuevo.'**
  String get feedbackSessionExpired;

  /// No description provided for @feedbackSessionRevoked.
  ///
  /// In es, this message translates to:
  /// **'Tu sesión terminó. Inicia sesión de nuevo.'**
  String get feedbackSessionRevoked;

  /// No description provided for @feedbackSsoUnavailable.
  ///
  /// In es, this message translates to:
  /// **'Esa sesión ya no está disponible. Inicia sesión para continuar.'**
  String get feedbackSsoUnavailable;

  /// No description provided for @feedbackProviderUnavailable.
  ///
  /// In es, this message translates to:
  /// **'Esa opción de inicio de sesión no está disponible en este dispositivo.'**
  String get feedbackProviderUnavailable;

  /// No description provided for @feedbackUnexpected.
  ///
  /// In es, this message translates to:
  /// **'Algo salió mal. Inténtalo de nuevo.'**
  String get feedbackUnexpected;

  /// No description provided for @emailRequired.
  ///
  /// In es, this message translates to:
  /// **'Ingresa tu correo'**
  String get emailRequired;

  /// No description provided for @emailInvalid.
  ///
  /// In es, this message translates to:
  /// **'Ingresa un correo válido'**
  String get emailInvalid;

  /// No description provided for @passwordRequired.
  ///
  /// In es, this message translates to:
  /// **'Ingresa tu contraseña'**
  String get passwordRequired;

  /// No description provided for @codeRequired.
  ///
  /// In es, this message translates to:
  /// **'Ingresa el código'**
  String get codeRequired;

  /// No description provided for @legalTermsLabel.
  ///
  /// In es, this message translates to:
  /// **'Términos'**
  String get legalTermsLabel;

  /// No description provided for @legalPrivacyLabel.
  ///
  /// In es, this message translates to:
  /// **'Política de privacidad'**
  String get legalPrivacyLabel;

  /// Footer shown when both the terms-of-service and privacy-policy links are configured.
  ///
  /// In es, this message translates to:
  /// **'Al continuar, aceptas los {terms} y la {policy}.'**
  String legalFooterBoth(String terms, String policy);

  /// Footer shown when only the terms-of-service link is configured.
  ///
  /// In es, this message translates to:
  /// **'Al continuar, aceptas los {terms}.'**
  String legalFooterTermsOnly(String terms);

  /// Footer shown when only the privacy-policy link is configured.
  ///
  /// In es, this message translates to:
  /// **'Al continuar, aceptas la {policy}.'**
  String legalFooterPolicyOnly(String policy);
}

class _LoginFlowLocalizationsDelegate
    extends LocalizationsDelegate<LoginFlowLocalizations> {
  const _LoginFlowLocalizationsDelegate();

  @override
  Future<LoginFlowLocalizations> load(Locale locale) {
    return SynchronousFuture<LoginFlowLocalizations>(
      lookupLoginFlowLocalizations(locale),
    );
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'es'].contains(locale.languageCode);

  @override
  bool shouldReload(_LoginFlowLocalizationsDelegate old) => false;
}

LoginFlowLocalizations lookupLoginFlowLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return LoginFlowLocalizationsEn();
    case 'es':
      return LoginFlowLocalizationsEs();
  }

  throw FlutterError(
    'LoginFlowLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
