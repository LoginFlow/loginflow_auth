// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'login_flow_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Spanish Castilian (`es`).
class LoginFlowLocalizationsEs extends LoginFlowLocalizations {
  LoginFlowLocalizationsEs([String locale = 'es']) : super(locale);

  @override
  String get signInTitle => 'Iniciar sesión';

  @override
  String get signInSubtitle => 'Elige cómo quieres continuar';

  @override
  String get continueWithPassword => 'Continuar con contraseña';

  @override
  String get continueWithEmailCode => 'Enviarme un código por correo';

  @override
  String get continueWithGoogle => 'Continuar con Google';

  @override
  String get continueWithMicrosoft => 'Continuar con Microsoft';

  @override
  String get continueWithApple => 'Continuar con Apple';

  @override
  String get continueWithFacebook => 'Continuar con Facebook';

  @override
  String get continueWithPasskey => 'Continuar con una llave de acceso';

  @override
  String get temporaryAccessPassTitle => 'Código temporal de acceso';

  @override
  String get temporaryAccessPassInstructions =>
      'Ingresa el código temporal de acceso que te dio tu administrador.';

  @override
  String get useTemporaryAccessPass => 'Usar un código temporal de acceso';

  @override
  String get emailLabel => 'Correo electrónico';

  @override
  String get passwordLabel => 'Contraseña';

  @override
  String get showPassword => 'Mostrar contraseña';

  @override
  String get hidePassword => 'Ocultar contraseña';

  @override
  String get signInButton => 'Iniciar sesión';

  @override
  String get forgotPassword => '¿Olvidaste tu contraseña?';

  @override
  String get sendCodeButton => 'Enviar código';

  @override
  String get codeLabel => 'Código';

  @override
  String codeSentTo(String email) {
    return 'Enviamos un código a $email';
  }

  @override
  String get verifyButton => 'Verificar';

  @override
  String get resendCode => 'Reenviar código';

  @override
  String resendIn(int seconds) {
    return 'Reenviar código en $seconds s';
  }

  @override
  String get sendMagicLink => 'Enviarme un enlace de inicio de sesión';

  @override
  String get twoStepTitle => 'Verificación en dos pasos';

  @override
  String get authenticatorInstructions =>
      'Ingresa el código de 6 dígitos de tu app de autenticación.';

  @override
  String get recoveryInstructions =>
      'Ingresa uno de tus códigos de recuperación.';

  @override
  String get useRecoveryCode => 'Usar un código de recuperación';

  @override
  String get useAuthenticatorCode => 'Usar tu app de autenticación';

  @override
  String get back => 'Volver';

  @override
  String get createAccount => 'Crear una cuenta';

  @override
  String get continueInBrowser => 'Continúa en tu navegador…';

  @override
  String continueAs(String name) {
    return 'Continuar como $name';
  }

  @override
  String get ssoSubtitle =>
      'Ya iniciaste sesión en otra app de este dispositivo.';

  @override
  String get useAnotherAccount => 'Usar otra cuenta';

  @override
  String get lockedOutTitle => 'Demasiados intentos';

  @override
  String lockedOutMessage(int seconds) {
    return 'Vuelve a intentarlo en $seconds segundos.';
  }

  @override
  String get tryAgain => 'Reintentar';

  @override
  String get optionsUnavailable =>
      'No se pudieron cargar las opciones de inicio de sesión.';

  @override
  String get noMethods =>
      'No hay métodos de inicio de sesión disponibles para esta app.';

  @override
  String get notConfigured => 'El inicio de sesión no está configurado.';

  @override
  String get feedbackInvalidCredential =>
      'Los datos que ingresaste no son correctos.';

  @override
  String get feedbackCodeExpired => 'El código venció. Solicita uno nuevo.';

  @override
  String get feedbackNetwork => 'Revisa tu conexión e inténtalo de nuevo.';

  @override
  String get feedbackSessionExpired =>
      'El inicio de sesión tardó demasiado. Empieza de nuevo.';

  @override
  String get feedbackSessionRevoked =>
      'Tu sesión terminó. Inicia sesión de nuevo.';

  @override
  String get feedbackSsoUnavailable =>
      'Esa sesión ya no está disponible. Inicia sesión para continuar.';

  @override
  String get feedbackProviderUnavailable =>
      'Esa opción de inicio de sesión no está disponible en este dispositivo.';

  @override
  String get feedbackUnexpected => 'Algo salió mal. Inténtalo de nuevo.';

  @override
  String get emailRequired => 'Ingresa tu correo';

  @override
  String get emailInvalid => 'Ingresa un correo válido';

  @override
  String get passwordRequired => 'Ingresa tu contraseña';

  @override
  String get codeRequired => 'Ingresa el código';

  @override
  String get legalTermsLabel => 'Términos';

  @override
  String get legalPrivacyLabel => 'Política de privacidad';

  @override
  String legalFooterBoth(String terms, String policy) {
    return 'Al continuar, aceptas los $terms y la $policy.';
  }

  @override
  String legalFooterTermsOnly(String terms) {
    return 'Al continuar, aceptas los $terms.';
  }

  @override
  String legalFooterPolicyOnly(String policy) {
    return 'Al continuar, aceptas la $policy.';
  }

  @override
  String get useAccessCode => 'Tengo un código de acceso';

  @override
  String get accessCodeTitle => 'Código de acceso';

  @override
  String get accessCodeInstructions =>
      'Ingresa el código de acceso que te entregaron.';

  @override
  String get accessCodeHint => 'XXXX-XXXX';

  @override
  String accessCodeIncomplete(int length) {
    return 'Ingresa los $length caracteres del código';
  }

  @override
  String get feedbackInvalidAccessCode =>
      'Ese código de acceso no es válido: puede estar mal escrito, vencido o ya usado. Revísalo o pide uno nuevo.';

  @override
  String get feedbackAccessCodesUnavailable =>
      'Los códigos de acceso no están disponibles para esta app.';

  @override
  String get feedbackAccessCodeNotConfigured =>
      'Esta app no está configurada para iniciar sesión con códigos de acceso.';

  @override
  String get passkeysTitle => 'Llaves de acceso';

  @override
  String get passkeysSubtitle =>
      'Inicia sesión sin contraseña con el bloqueo de pantalla de tu dispositivo.';

  @override
  String get passkeysEmpty => 'Todavía no tienes llaves de acceso.';

  @override
  String get passkeysLoadFailed =>
      'No se pudieron cargar tus llaves de acceso.';

  @override
  String get passkeysSignedOut =>
      'Inicia sesión para administrar tus llaves de acceso.';

  @override
  String get addPasskey => 'Agregar una llave de acceso';

  @override
  String get passkeyUnnamed => 'Llave de acceso';

  @override
  String passkeyAddedOn(String date) {
    return 'Agregada el $date';
  }

  @override
  String passkeyLastUsedOn(String date) {
    return 'Usada por última vez el $date';
  }

  @override
  String get renamePasskey => 'Cambiar nombre';

  @override
  String get deletePasskey => 'Eliminar';

  @override
  String get passkeyNameLabel => 'Nombre';

  @override
  String get passkeyNameRequired => 'Ingresa un nombre';

  @override
  String get saveButton => 'Guardar';

  @override
  String get cancelButton => 'Cancelar';

  @override
  String get deletePasskeyTitle => '¿Eliminar esta llave de acceso?';

  @override
  String deletePasskeyMessage(String name) {
    return 'Ya no podrás iniciar sesión con «$name».';
  }

  @override
  String get reauthenticateTitle => 'Confirma que eres tú';

  @override
  String get reauthenticateMessage =>
      'Para agregar una llave de acceso, vuelve a iniciar sesión.';

  @override
  String get feedbackPasskeyNotConfigured =>
      'Las llaves de acceso no están configuradas en esta app.';

  @override
  String get feedbackPasskeyNotSupported =>
      'Este dispositivo no puede usar llaves de acceso.';

  @override
  String get feedbackPasskeyNoCredentials =>
      'No hay ninguna llave de acceso disponible en este dispositivo.';

  @override
  String get feedbackPasskeySecurityError =>
      'Esta app no tiene permiso para usar llaves de acceso de esta cuenta.';

  @override
  String get feedbackPasskeyDomainNotAssociated =>
      'Esta app todavía no está vinculada al dominio de las llaves de acceso.';

  @override
  String get feedbackPasskeyAlreadyRegistered =>
      'Este dispositivo ya tiene una llave de acceso para tu cuenta.';

  @override
  String get feedbackPasskeyTimeout =>
      'La llave de acceso tardó demasiado en responder. Inténtalo de nuevo.';

  @override
  String get feedbackPasskeyInvalidResponse =>
      'El dispositivo devolvió una respuesta no válida. Inténtalo de nuevo.';

  @override
  String get feedbackPasskeyFailed => 'No se pudo crear la llave de acceso.';

  @override
  String get feedbackPasskeyNotFound => 'Esa llave de acceso ya no existe.';

  @override
  String get feedbackPasskeysUnavailable =>
      'Las llaves de acceso no están disponibles para esta cuenta.';

  @override
  String get feedbackReauthenticationRequired =>
      'Vuelve a iniciar sesión para agregar una llave de acceso.';

  @override
  String get feedbackRateLimited =>
      'Demasiados intentos. Espera un momento e inténtalo de nuevo.';
}
