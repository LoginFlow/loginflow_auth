import 'package:loginflow_auth/src/core/json/json_field_reader.dart';

/// A primary sign-in method the app offers, with its own options.
///
/// Cases exist only for implemented methods; a new method (passkeys) is
/// added as a new case when it is implemented, and every `switch` over
/// [AuthMethod] then fails to compile until it is handled.
sealed class AuthMethod {
  const AuthMethod();

  factory AuthMethod.fromJson(Map<String, Object?> json) {
    final method = json.requireString('method');
    return switch (method) {
      PasswordMethod.methodName => PasswordMethod.fromJson(json),
      EmailOtpMethod.methodName => EmailOtpMethod.fromJson(json),
      GoogleMethod.methodName => const GoogleMethod(),
      MicrosoftMethod.methodName => const MicrosoftMethod(),
      AppleMethod.methodName => const AppleMethod(),
      FacebookMethod.methodName => const FacebookMethod(),
      _ => throw FormatException('Unknown sign-in method "$method".'),
    };
  }

  /// The name the server uses in `login_methods`.
  String get wireName;

  Map<String, Object?> toJson();
}

/// Email and password.
final class PasswordMethod extends AuthMethod {
  const PasswordMethod({this.isForgotPasswordShown = true});

  factory PasswordMethod.fromJson(Map<String, Object?> json) => PasswordMethod(
    isForgotPasswordShown: json.optionalBool(
      'forgot_password_shown',
      absent: true,
    ),
  );

  static const String methodName = 'password';

  /// Shows "Forgot your password?" when the server also enables reset.
  final bool isForgotPasswordShown;

  @override
  String get wireName => methodName;

  PasswordMethod copyWith({bool? isForgotPasswordShown}) => PasswordMethod(
    isForgotPasswordShown: isForgotPasswordShown ?? this.isForgotPasswordShown,
  );

  @override
  Map<String, Object?> toJson() => <String, Object?>{
    'method': methodName,
    'forgot_password_shown': isForgotPasswordShown,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PasswordMethod &&
          isForgotPasswordShown == other.isForgotPasswordShown;

  @override
  int get hashCode => Object.hash(methodName, isForgotPasswordShown);
}

/// A one-time code sent by email.
final class EmailOtpMethod extends AuthMethod {
  const EmailOtpMethod({this.resendCooldown = const Duration(seconds: 30)});

  factory EmailOtpMethod.fromJson(Map<String, Object?> json) => EmailOtpMethod(
    resendCooldown: Duration(
      seconds: json.optionalInt('resend_cooldown_seconds') ?? 30,
    ),
  );

  static const String methodName = 'email_otp';

  /// Wait before "Resend code" is enabled again.
  final Duration resendCooldown;

  @override
  String get wireName => methodName;

  EmailOtpMethod copyWith({Duration? resendCooldown}) =>
      EmailOtpMethod(resendCooldown: resendCooldown ?? this.resendCooldown);

  @override
  Map<String, Object?> toJson() => <String, Object?>{
    'method': methodName,
    'resend_cooldown_seconds': resendCooldown.inSeconds,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is EmailOtpMethod && resendCooldown == other.resendCooldown;

  @override
  int get hashCode => Object.hash(methodName, resendCooldown);
}

/// Google: native token when `loginflow_auth_google` is configured,
/// otherwise the system browser.
final class GoogleMethod extends AuthMethod {
  const GoogleMethod();

  static const String methodName = 'google';

  @override
  String get wireName => methodName;

  GoogleMethod copyWith() => const GoogleMethod();

  @override
  Map<String, Object?> toJson() => <String, Object?>{'method': methodName};

  @override
  bool operator ==(Object other) => other is GoogleMethod;

  @override
  int get hashCode => methodName.hashCode;
}

/// Microsoft: always through the system browser.
final class MicrosoftMethod extends AuthMethod {
  const MicrosoftMethod();

  static const String methodName = 'microsoft';

  @override
  String get wireName => methodName;

  MicrosoftMethod copyWith() => const MicrosoftMethod();

  @override
  Map<String, Object?> toJson() => <String, Object?>{'method': methodName};

  @override
  bool operator ==(Object other) => other is MicrosoftMethod;

  @override
  int get hashCode => methodName.hashCode;
}

/// Apple: native `AuthenticationServices` on iOS/macOS when
/// `loginflow_auth_apple` is configured, otherwise the system browser —
/// including Android, where the native ceremony is never used.
final class AppleMethod extends AuthMethod {
  const AppleMethod();

  static const String methodName = 'apple';

  @override
  String get wireName => methodName;

  AppleMethod copyWith() => const AppleMethod();

  @override
  Map<String, Object?> toJson() => <String, Object?>{'method': methodName};

  @override
  bool operator ==(Object other) => other is AppleMethod;

  @override
  int get hashCode => methodName.hashCode;
}

/// Facebook: native Limited Login (iOS) / classic login (Android) when
/// `loginflow_auth_facebook` is configured, otherwise the system browser.
final class FacebookMethod extends AuthMethod {
  const FacebookMethod();

  static const String methodName = 'facebook';

  @override
  String get wireName => methodName;

  FacebookMethod copyWith() => const FacebookMethod();

  @override
  Map<String, Object?> toJson() => <String, Object?>{'method': methodName};

  @override
  bool operator ==(Object other) => other is FacebookMethod;

  @override
  int get hashCode => methodName.hashCode;
}
