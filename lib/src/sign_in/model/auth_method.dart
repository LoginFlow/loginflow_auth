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

  /// The JSON form of this [AuthMethod], read back by [AuthMethod.fromJson].
  Map<String, Object?> toJson();
}

/// Email and password.
final class PasswordMethod extends AuthMethod {
  /// Creates a [PasswordMethod].
  const PasswordMethod({this.isForgotPasswordShown = true});

  /// Reads a [PasswordMethod] from its JSON form ([toJson]).
  factory PasswordMethod.fromJson(Map<String, Object?> json) => PasswordMethod(
    isForgotPasswordShown: json.optionalBool(
      'forgot_password_shown',
      absent: true,
    ),
  );

  /// The wire name of this method in the login options.
  static const String methodName = 'password';

  /// Shows "Forgot your password?" when the server also enables reset.
  final bool isForgotPasswordShown;

  @override
  String get wireName => methodName;

  /// A copy of this [PasswordMethod] with the given fields replaced.
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
  /// Creates an [EmailOtpMethod].
  const EmailOtpMethod({this.resendCooldown = const Duration(seconds: 30)});

  /// Reads an [EmailOtpMethod] from its JSON form ([toJson]).
  factory EmailOtpMethod.fromJson(Map<String, Object?> json) => EmailOtpMethod(
    resendCooldown: Duration(
      seconds: json.optionalInt('resend_cooldown_seconds') ?? 30,
    ),
  );

  /// The wire name of this method in the login options.
  static const String methodName = 'email_otp';

  /// Wait before "Resend code" is enabled again.
  final Duration resendCooldown;

  @override
  String get wireName => methodName;

  /// A copy of this [EmailOtpMethod] with the given fields replaced.
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
  /// Creates a [GoogleMethod].
  const GoogleMethod();

  /// The wire name of this method in the login options.
  static const String methodName = 'google';

  @override
  String get wireName => methodName;

  /// A copy of this [GoogleMethod] with the given fields replaced.
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
  /// Creates a [MicrosoftMethod].
  const MicrosoftMethod();

  /// The wire name of this method in the login options.
  static const String methodName = 'microsoft';

  @override
  String get wireName => methodName;

  /// A copy of this [MicrosoftMethod] with the given fields replaced.
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
  /// Creates an [AppleMethod].
  const AppleMethod();

  /// The wire name of this method in the login options.
  static const String methodName = 'apple';

  @override
  String get wireName => methodName;

  /// A copy of this [AppleMethod] with the given fields replaced.
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
  /// Creates a [FacebookMethod].
  const FacebookMethod();

  /// The wire name of this method in the login options.
  static const String methodName = 'facebook';

  @override
  String get wireName => methodName;

  /// A copy of this [FacebookMethod] with the given fields replaced.
  FacebookMethod copyWith() => const FacebookMethod();

  @override
  Map<String, Object?> toJson() => <String, Object?>{'method': methodName};

  @override
  bool operator ==(Object other) => other is FacebookMethod;

  @override
  int get hashCode => methodName.hashCode;
}
