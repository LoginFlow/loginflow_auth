import 'dart:convert';

import 'package:loginflow_auth/src/core/protocol/challenge/challenge_step.dart';
import 'package:loginflow_auth/src/core/protocol/challenge/upstream_flow.dart';
import 'package:loginflow_auth/src/core/protocol/challenge/upstream_provider.dart';
import 'package:loginflow_auth/src/core/protocol/challenge/upstream_token_type.dart';

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

/// Asks the server to send one email carrying both a fresh email-OTP code
/// and a magic-link token bound to this transaction (contract: magic
/// link). Reached from the `email_otp` step's "email me a sign-in link
/// instead" action, only when `ClientLoginOptions.isMagicLinkOffered`.
final class RequestMagicLinkInput extends ChallengeInput {
  const RequestMagicLinkInput();

  RequestMagicLinkInput copyWith() => const RequestMagicLinkInput();

  @override
  Map<String, String> toFormFields() => <String, String>{
    'method': ChallengeStep.magicLink.wireName,
  };

  @override
  bool operator ==(Object other) => other is RequestMagicLinkInput;

  @override
  int get hashCode => (RequestMagicLinkInput).hashCode;
}

/// Exchanges a magic-link token intercepted from a
/// `https://<company host>/login/magic/<client_id>?token=...` Android App
/// Link / iOS Universal Link, bound to the SAME `auth_session` the app
/// opened the sign-in attempt with (contract: magic link §3).
final class MagicLinkTokenInput extends ChallengeInput {
  const MagicLinkTokenInput({required this.token});

  final String token;

  MagicLinkTokenInput copyWith({String? token}) =>
      MagicLinkTokenInput(token: token ?? this.token);

  @override
  Map<String, String> toFormFields() => <String, String>{
    'magic_link_token': token,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MagicLinkTokenInput && token == other.token;

  @override
  int get hashCode => token.hashCode;
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

/// Answer to `next: upstream_token`: the provider token, typed by
/// [tokenType] (`doc/server-contract.md` §5.4), plus — on Apple's first
/// authorization only — the name Apple returned once.
final class UpstreamTokenInput extends ChallengeInput {
  const UpstreamTokenInput({
    required this.provider,
    required this.token,
    this.tokenType = UpstreamTokenType.idToken,
    this.givenName,
    this.familyName,
  });

  final UpstreamProvider provider;
  final String token;
  final UpstreamTokenType tokenType;
  final String? givenName;
  final String? familyName;

  UpstreamTokenInput copyWith({
    UpstreamProvider? provider,
    String? token,
    UpstreamTokenType? tokenType,
    String? givenName,
    String? familyName,
  }) => UpstreamTokenInput(
    provider: provider ?? this.provider,
    token: token ?? this.token,
    tokenType: tokenType ?? this.tokenType,
    givenName: givenName ?? this.givenName,
    familyName: familyName ?? this.familyName,
  );

  @override
  Map<String, String> toFormFields() => <String, String>{
    'upstream_provider': provider.wireName,
    'upstream_token': token,
    'upstream_token_type': tokenType.wireName,
    'upstream_user_name': ?_userName,
  };

  String? get _userName {
    final name = <String>[?givenName, ?familyName].join(' ').trim();
    return name.isEmpty ? null : name;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UpstreamTokenInput &&
          provider == other.provider &&
          token == other.token &&
          tokenType == other.tokenType &&
          givenName == other.givenName &&
          familyName == other.familyName;

  @override
  int get hashCode =>
      Object.hash(provider, token, tokenType, givenName, familyName);
}

/// Answer to `next: webauthn_assertion`: the raw `PublicKeyCredential` JSON a
/// WebAuthn client produces from the options carried on the `identify` leg
/// (`PasskeyAuthenticator.getAssertion`). Sent as a JSON-encoded string form
/// field, since form-urlencoded has no native nested shape.
final class WebauthnAssertionInput extends ChallengeInput {
  const WebauthnAssertionInput({required this.assertion});

  final Map<String, Object?> assertion;

  WebauthnAssertionInput copyWith({Map<String, Object?>? assertion}) =>
      WebauthnAssertionInput(assertion: assertion ?? this.assertion);

  @override
  Map<String, String> toFormFields() => <String, String>{
    'webauthn_assertion': jsonEncode(assertion),
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WebauthnAssertionInput &&
          jsonEncode(assertion) == jsonEncode(other.assertion);

  @override
  int get hashCode => jsonEncode(assertion).hashCode;
}

/// Identifier plus an admin-issued, single-use Temporary Access Pass in one
/// request — the opening leg, since the server never prompts for this
/// method (`doc/server-contract.md` passkeys section, "identified by the
/// transaction's `login_hint` like `password`").
final class TemporaryAccessPassSignInInput extends ChallengeInput {
  const TemporaryAccessPassSignInInput({
    required this.loginHint,
    required this.code,
  });

  final String loginHint;
  final String code;

  TemporaryAccessPassSignInInput copyWith({String? loginHint, String? code}) =>
      TemporaryAccessPassSignInInput(
        loginHint: loginHint ?? this.loginHint,
        code: code ?? this.code,
      );

  @override
  Map<String, String> toFormFields() => <String, String>{
    'login_hint': loginHint,
    'temporary_access_pass': code,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TemporaryAccessPassSignInInput &&
          loginHint == other.loginHint &&
          code == other.code;

  @override
  int get hashCode => Object.hash(loginHint, code);
}

/// Answer continuing an attempt whose identity is already bound to the
/// `auth_session` (step-up/reauthentication): just the code.
final class TemporaryAccessPassInput extends ChallengeInput {
  const TemporaryAccessPassInput({required this.code});

  final String code;

  TemporaryAccessPassInput copyWith({String? code}) =>
      TemporaryAccessPassInput(code: code ?? this.code);

  @override
  Map<String, String> toFormFields() => <String, String>{
    'temporary_access_pass': code,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TemporaryAccessPassInput && code == other.code;

  @override
  int get hashCode => code.hashCode;
}

/// A single-use access code, already normalized (`AccessCodeFormat`), in the
/// opening request (`doc/server-contract.md` §16). It identifies the subject
/// on its own, so no `login_hint` travels with it.
final class AccessCodeInput extends ChallengeInput {
  const AccessCodeInput({required this.code});

  final String code;

  AccessCodeInput copyWith({String? code}) =>
      AccessCodeInput(code: code ?? this.code);

  @override
  Map<String, String> toFormFields() => <String, String>{
    'method': ChallengeStep.accessCode.wireName,
    'access_code': code,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is AccessCodeInput && code == other.code;

  @override
  int get hashCode => code.hashCode;
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
