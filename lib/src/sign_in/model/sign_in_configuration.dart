import 'package:loginflow_auth/src/core/json/json_field_reader.dart';
import 'package:loginflow_auth/src/core/json/list_equality.dart';
import 'package:loginflow_auth/src/sign_in/model/auth_method.dart';
import 'package:loginflow_auth/src/sign_in/model/sign_in_copy.dart';

/// What the built-in sign-in UI offers.
///
/// The UI renders [methods] in this order, intersected with what the server
/// enables for the client: a method the server does not allow is never
/// shown. With a single resulting method the UI opens it directly. A TOTP
/// step is shown automatically whenever the server asks for one.
class SignInConfiguration {
  const SignInConfiguration({
    required this.methods,
    this.isSelfSignUpOffered = false,
    this.isPasskeySignInOffered = true,
    this.isPasskeyAutoSuggestOffered = false,
    this.isTemporaryAccessPassOffered = false,
    this.copy = const SignInCopy(),
  });

  factory SignInConfiguration.fromJson(Map<String, Object?> json) {
    final rawMethods = json['methods'];
    if (rawMethods is! List<Object?>) {
      throw const FormatException('Field "methods" must be an array.');
    }
    final copy = json.optionalObject('copy');
    return SignInConfiguration(
      methods: List<AuthMethod>.unmodifiable(
        rawMethods.whereType<Map<String, Object?>>().map(AuthMethod.fromJson),
      ),
      isSelfSignUpOffered: json.optionalBool('self_signup', absent: false),
      isPasskeySignInOffered: json.optionalBool(
        'passkey_sign_in',
        absent: true,
      ),
      isPasskeyAutoSuggestOffered: json.optionalBool(
        'passkey_auto_suggest',
        absent: false,
      ),
      isTemporaryAccessPassOffered: json.optionalBool(
        'temporary_access_pass',
        absent: false,
      ),
      copy: copy == null ? const SignInCopy() : SignInCopy.fromJson(copy),
    );
  }

  final List<AuthMethod> methods;

  /// "Create an account" is shown only if this is true AND the server
  /// enables self sign-up for the client.
  final bool isSelfSignUpOffered;

  /// Allows "Sign in with a passkey" on the method picker. Defaults to
  /// `true`: the server is the source of truth for whether a passkey may
  /// be a first factor at all (`ClientLoginOptions.isFirstFactorPasskeyOffered`,
  /// `doc/server-contract.md` §4) — set this to `false` only to hide a
  /// passkey the server would otherwise allow, never to show one it does
  /// not. With the company's passkey policy set to `mfa_only`, a passkey
  /// is still used automatically as a *second* factor mid-challenge; this
  /// flag and [isPasskeyAutoSuggestOffered] only control the first-factor
  /// button and auto-suggest, neither of which the server offers in that
  /// mode.
  final bool isPasskeySignInOffered;

  /// On the first screen of a fresh sign-in, silently tries a discoverable
  /// passkey sign-in (`LoginFlowAuth.signInWithPasskey()` with no
  /// `login_hint`) before the user picks anything — the platform's own
  /// modal passkey sheet (Android Credential Manager, iOS/macOS
  /// AuthenticationServices, the browser's passkey dialog), never an
  /// autofill-only (conditional) request. A failure (no saved passkey, user
  /// dismissed, not supported, timed out) falls back to the normal picker
  /// without showing an error; only a manual tap on the passkey button
  /// surfaces one. Has no effect when [isPasskeySignInOffered] is `false`,
  /// or when the server does not offer a passkey as a first factor.
  final bool isPasskeyAutoSuggestOffered;

  /// Shows "Use a temporary access pass" on the entry screen (an
  /// admin-issued, single-use recovery code — `doc/server-contract.md`
  /// §5.7). Like [isPasskeySignInOffered], never gated by `login_methods`.
  final bool isTemporaryAccessPassOffered;
  final SignInCopy copy;

  SignInConfiguration copyWith({
    List<AuthMethod>? methods,
    bool? isSelfSignUpOffered,
    bool? isPasskeySignInOffered,
    bool? isPasskeyAutoSuggestOffered,
    bool? isTemporaryAccessPassOffered,
    SignInCopy? copy,
  }) => SignInConfiguration(
    methods: methods ?? this.methods,
    isSelfSignUpOffered: isSelfSignUpOffered ?? this.isSelfSignUpOffered,
    isPasskeySignInOffered:
        isPasskeySignInOffered ?? this.isPasskeySignInOffered,
    isPasskeyAutoSuggestOffered:
        isPasskeyAutoSuggestOffered ?? this.isPasskeyAutoSuggestOffered,
    isTemporaryAccessPassOffered:
        isTemporaryAccessPassOffered ?? this.isTemporaryAccessPassOffered,
    copy: copy ?? this.copy,
  );

  Map<String, Object?> toJson() => <String, Object?>{
    'methods': methods.map((method) => method.toJson()).toList(),
    'self_signup': isSelfSignUpOffered,
    'passkey_sign_in': isPasskeySignInOffered,
    'passkey_auto_suggest': isPasskeyAutoSuggestOffered,
    'temporary_access_pass': isTemporaryAccessPassOffered,
    'copy': copy.toJson(),
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SignInConfiguration &&
          methods.hasSameValues(other.methods) &&
          isSelfSignUpOffered == other.isSelfSignUpOffered &&
          isPasskeySignInOffered == other.isPasskeySignInOffered &&
          isPasskeyAutoSuggestOffered == other.isPasskeyAutoSuggestOffered &&
          isTemporaryAccessPassOffered ==
              other.isTemporaryAccessPassOffered &&
          copy == other.copy;

  @override
  int get hashCode => Object.hash(
    methods.valuesHash,
    isSelfSignUpOffered,
    isPasskeySignInOffered,
    isPasskeyAutoSuggestOffered,
    isTemporaryAccessPassOffered,
    copy,
  );
}
