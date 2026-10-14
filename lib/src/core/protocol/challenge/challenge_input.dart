import 'package:loginflow_auth/src/core/protocol/challenge/challenge_step.dart';
import 'package:loginflow_auth/src/core/protocol/challenge/upstream_flow.dart';
import 'package:loginflow_auth/src/core/protocol/challenge/upstream_provider.dart';

/// The user input carried by one challenge request: the deployment-defined
/// step parameters of the LoginFlow profile
/// (draft-ietf-oauth-first-party-apps-04 §5.1 and Appendix B).
///
/// Inputs are request payloads serialized only to form fields
/// ([toFormFields]); they are never stored or parsed back, so they have no
/// `toJson`/`fromJson`, and `toString` never prints secrets.
sealed class ChallengeInput {
  const ChallengeInput();

  Map<String, String> toFormFields();

  @override
  String toString() => '$runtimeType(<redacted>)';
}

/// Identifier plus password in one request.
final class PasswordSignInInput extends ChallengeInput {
  const PasswordSignInInput({required this.loginHint, required this.password});

  final String loginHint;
  final String password;

  PasswordSignInInput copyWith({String? loginHint, String? password}) =>
      PasswordSignInInput(
        loginHint: loginHint ?? this.loginHint,
        password: password ?? this.password,
      );

  @override
  Map<String, String> toFormFields() => <String, String>{
    'login_hint': loginHint,
    'password': password,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PasswordSignInInput &&
          loginHint == other.loginHint &&
          password == other.password;

  @override
  int get hashCode => Object.hash(loginHint, password);
}

/// Only the identifier; the server decides the next step.
final class LoginHintInput extends ChallengeInput {
  const LoginHintInput({required this.loginHint});

  final String loginHint;

  LoginHintInput copyWith({String? loginHint}) =>
      LoginHintInput(loginHint: loginHint ?? this.loginHint);

  @override
  Map<String, String> toFormFields() => <String, String>{
    'login_hint': loginHint,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LoginHintInput && loginHint == other.loginHint;

  @override
  int get hashCode => loginHint.hashCode;
}

/// Identifier plus the method to continue with (e.g. `email_otp`, which makes
/// the server send the code as a side effect).
final class IdentifierInput extends ChallengeInput {
  const IdentifierInput({required this.loginHint, required this.method});

  final String loginHint;
  final ChallengeStep method;

  IdentifierInput copyWith({String? loginHint, ChallengeStep? method}) =>
      IdentifierInput(
        loginHint: loginHint ?? this.loginHint,
        method: method ?? this.method,
      );

  @override
  Map<String, String> toFormFields() => <String, String>{
    'login_hint': loginHint,
    'method': method.wireName,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is IdentifierInput &&
          loginHint == other.loginHint &&
          method == other.method;

  @override
  int get hashCode => Object.hash(loginHint, method);
}

/// Answer to `next: password`.
final class PasswordInput extends ChallengeInput {
  const PasswordInput({required this.password});

  final String password;

  PasswordInput copyWith({String? password}) =>
      PasswordInput(password: password ?? this.password);

  @override
  Map<String, String> toFormFields() => <String, String>{'password': password};

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PasswordInput && password == other.password;

  @override
  int get hashCode => password.hashCode;
}

/// Answer to `next: email_otp`.
final class EmailOtpInput extends ChallengeInput {
  const EmailOtpInput({required this.code});

  final String code;

  EmailOtpInput copyWith({String? code}) =>
      EmailOtpInput(code: code ?? this.code);

  @override
  Map<String, String> toFormFields() => <String, String>{'email_otp': code};

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is EmailOtpInput && code == other.code;

  @override
  int get hashCode => code.hashCode;
}

/// Asks the server to send a new email OTP.
final class ResendEmailOtpInput extends ChallengeInput {
  const ResendEmailOtpInput();

  ResendEmailOtpInput copyWith() => const ResendEmailOtpInput();

  @override
  Map<String, String> toFormFields() => <String, String>{
    'resend': ChallengeStep.emailOtp.wireName,
  };

  @override
  bool operator ==(Object other) => other is ResendEmailOtpInput;

  @override
  int get hashCode => (ResendEmailOtpInput).hashCode;
}

/// Answer to `next: totp`.
final class TotpInput extends ChallengeInput {
  const TotpInput({required this.code});

  final String code;

  TotpInput copyWith({String? code}) => TotpInput(code: code ?? this.code);

  @override
  Map<String, String> toFormFields() => <String, String>{'totp': code};

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is TotpInput && code == other.code;

  @override
  int get hashCode => code.hashCode;
}

/// Answer to `next: recovery_code` (TOTP fallback).
final class RecoveryCodeInput extends ChallengeInput {
  const RecoveryCodeInput({required this.code});

  final String code;

  RecoveryCodeInput copyWith({String? code}) =>
      RecoveryCodeInput(code: code ?? this.code);

  @override
  Map<String, String> toFormFields() => <String, String>{'recovery_code': code};

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RecoveryCodeInput && code == other.code;

  @override
  int get hashCode => code.hashCode;
}

/// Answer to `next: select_method`, or a switch to one of `methods`.
final class MethodSelectionInput extends ChallengeInput {
  const MethodSelectionInput({required this.method});

  final ChallengeStep method;

  MethodSelectionInput copyWith({ChallengeStep? method}) =>
      MethodSelectionInput(method: method ?? this.method);

  @override
  Map<String, String> toFormFields() => <String, String>{
    'method': method.wireName,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MethodSelectionInput && method == other.method;

  @override
  int get hashCode => method.hashCode;
}

/// Starts a federated sign-in with [provider].
final class UpstreamStartInput extends ChallengeInput {
  const UpstreamStartInput({required this.provider, required this.flow});

  final UpstreamProvider provider;
  final UpstreamFlow flow;

  UpstreamStartInput copyWith({
    UpstreamProvider? provider,
    UpstreamFlow? flow,
  }) => UpstreamStartInput(
    provider: provider ?? this.provider,
    flow: flow ?? this.flow,
  );

  @override
  Map<String, String> toFormFields() => <String, String>{
    'upstream_provider': provider.wireName,
    'upstream_flow': flow.wireName,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UpstreamStartInput &&
          provider == other.provider &&
          flow == other.flow;

  @override
  int get hashCode => Object.hash(provider, flow);
}

/// Answer to `next: upstream_token`: the provider ID token.
final class UpstreamTokenInput extends ChallengeInput {
  const UpstreamTokenInput({required this.provider, required this.idToken});

  final UpstreamProvider provider;
  final String idToken;

  UpstreamTokenInput copyWith({UpstreamProvider? provider, String? idToken}) =>
      UpstreamTokenInput(
        provider: provider ?? this.provider,
        idToken: idToken ?? this.idToken,
      );

  @override
  Map<String, String> toFormFields() => <String, String>{
    'upstream_provider': provider.wireName,
    'upstream_token': idToken,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UpstreamTokenInput &&
          provider == other.provider &&
          idToken == other.idToken;

  @override
  int get hashCode => Object.hash(provider, idToken);
}

/// Asks for the hosted password-reset flow (answered with `redirect_to_web`).
final class PasswordResetInput extends ChallengeInput {
  const PasswordResetInput({this.loginHint});

  final String? loginHint;

  PasswordResetInput copyWith({String? loginHint}) =>
      PasswordResetInput(loginHint: loginHint ?? this.loginHint);

  @override
  Map<String, String> toFormFields() => <String, String>{
    'intent': 'password_reset',
    'login_hint': ?loginHint,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PasswordResetInput && loginHint == other.loginHint;

  @override
  int get hashCode => loginHint.hashCode;
}
