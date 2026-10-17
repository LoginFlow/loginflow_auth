import 'package:logger_rs/logger_rs.dart';
import 'package:loginflow_auth/src/core/json/json_field_reader.dart';
import 'package:loginflow_auth/src/core/json/list_equality.dart';
import 'package:loginflow_auth/src/core/protocol/login_options/passkey_mode.dart';

/// What the server allows for this client (LoginFlow extension
/// `loginflow_login_options_endpoint`, `doc/server-contract.md` §4): the
/// primary login methods, self sign-up, password reset, the company's
/// passkey policy and, when Google is configured, the client ID a native
/// app needs for it.
class ClientLoginOptions {
  const ClientLoginOptions({
    required this.clientId,
    required this.loginMethods,
    required this.isSelfSignUpEnabled,
    required this.isPasswordResetEnabled,
    this.hasPasskey = false,
    this.passkeyMode,
    this.googleServerClientId,
    this.facebookAppId,
    this.policyUri,
    this.tosUri,
  });

  factory ClientLoginOptions.fromJson(Map<String, Object?> json) {
    final hasPasskey = json.optionalBool('passkey', absent: false);
    return ClientLoginOptions(
      clientId: json.requireString('client_id'),
      loginMethods: json.stringList('login_methods'),
      isSelfSignUpEnabled: json.optionalBool('self_signup', absent: false),
      isPasswordResetEnabled: json.optionalBool(
        'password_reset',
        absent: false,
      ),
      hasPasskey: hasPasskey,
      passkeyMode: hasPasskey ? _readPasskeyMode(json) : null,
      googleServerClientId: json.optionalString('google_server_client_id'),
      facebookAppId: json.optionalString('facebook_app_id'),
      policyUri: _readHttpsUri(json, 'policy_uri'),
      tosUri: _readHttpsUri(json, 'tos_uri'),
    );
  }

  /// Reads an optional RFC 7591 client-metadata URL field
  /// (`doc/server-contract.md` §4). A value present but malformed or not
  /// `https` is treated the same as absent — a cosmetic legal link is
  /// never worth refusing the whole options response over.
  static Uri? _readHttpsUri(Map<String, Object?> json, String field) {
    final raw = json.optionalString(field);
    if (raw == null) {
      return null;
    }
    final uri = Uri.tryParse(raw);
    if (uri == null || uri.scheme != 'https') {
      Log.w('Login options field "$field" is not an https URL: "$raw".');
      return null;
    }
    return uri;
  }

  static PasskeyMode _readPasskeyMode(Map<String, Object?> json) {
    final wireName = json.requireString('passkey_mode');
    final mode = PasskeyMode.fromWireName(wireName);
    if (mode == null) {
      throw FormatException('Unknown passkey mode "$wireName".');
    }
    return mode;
  }

  final String clientId;

  /// Wire names: `password`, `email_otp`, `google`, `microsoft`, `apple`,
  /// `facebook`. Unknown names are kept so newer server methods are simply
  /// not matched. `passkey` is never a member of this list (see
  /// [hasPasskey]).
  final List<String> loginMethods;
  final bool isSelfSignUpEnabled;
  final bool isPasswordResetEnabled;

  /// `true` when the company's passkey policy is not `disabled`. `false`
  /// means no passkey entry of any kind — first factor or second — is
  /// available, regardless of what the app is configured to show.
  final bool hasPasskey;

  /// Present only when [hasPasskey] is `true`.
  final PasskeyMode? passkeyMode;

  /// The Google OAuth client ID a native app needs for
  /// `CredentialManager`'s `GetGoogleIdOption`/`GoogleSignInOptions`. Not a
  /// secret. `null` when Google is not configured and enabled.
  final String? googleServerClientId;

  /// The Facebook App ID a native app needs for `FacebookAuth`/the Facebook
  /// SDK. Not a secret. `null` when Facebook is not configured and enabled.
  final String? facebookAppId;

  /// The company's privacy-policy page (RFC 7591 `policy_uri`). `null`
  /// when the company has not configured one.
  final Uri? policyUri;

  /// The company's terms-of-service page (RFC 7591 `tos_uri`). `null`
  /// when the company has not configured one.
  final Uri? tosUri;

  bool allows(String methodWireName) => loginMethods.contains(methodWireName);

  /// Whether the server publishes `magic_link` for this client — the
  /// "email me a sign-in link" action on the identifier/email-OTP step.
  bool get isMagicLinkOffered => allows('magic_link');

  /// Whether a passkey may be offered as its own first-factor button
  /// (`PasskeyMode.passwordless`). `false` when passkeys are disabled or
  /// restricted to [PasskeyMode.mfaOnly] — a passkey second factor still
  /// runs automatically mid-challenge in either of those cases, outside
  /// this flag's scope.
  bool get isFirstFactorPasskeyOffered =>
      hasPasskey && passkeyMode == PasskeyMode.passwordless;

  ClientLoginOptions copyWith({
    String? clientId,
    List<String>? loginMethods,
    bool? isSelfSignUpEnabled,
    bool? isPasswordResetEnabled,
    bool? hasPasskey,
    PasskeyMode? passkeyMode,
    String? googleServerClientId,
    String? facebookAppId,
    Uri? policyUri,
    Uri? tosUri,
  }) => ClientLoginOptions(
    clientId: clientId ?? this.clientId,
    loginMethods: loginMethods ?? this.loginMethods,
    isSelfSignUpEnabled: isSelfSignUpEnabled ?? this.isSelfSignUpEnabled,
    isPasswordResetEnabled:
        isPasswordResetEnabled ?? this.isPasswordResetEnabled,
    hasPasskey: hasPasskey ?? this.hasPasskey,
    passkeyMode: passkeyMode ?? this.passkeyMode,
    googleServerClientId: googleServerClientId ?? this.googleServerClientId,
    facebookAppId: facebookAppId ?? this.facebookAppId,
    policyUri: policyUri ?? this.policyUri,
    tosUri: tosUri ?? this.tosUri,
  );

  Map<String, Object?> toJson() => <String, Object?>{
    'client_id': clientId,
    'login_methods': loginMethods,
    'self_signup': isSelfSignUpEnabled,
    'password_reset': isPasswordResetEnabled,
    'passkey': hasPasskey,
    if (passkeyMode != null) 'passkey_mode': passkeyMode!.wireName,
    if (googleServerClientId != null)
      'google_server_client_id': googleServerClientId,
    if (facebookAppId != null) 'facebook_app_id': facebookAppId,
    if (policyUri != null) 'policy_uri': policyUri.toString(),
    if (tosUri != null) 'tos_uri': tosUri.toString(),
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ClientLoginOptions &&
          clientId == other.clientId &&
          loginMethods.hasSameValues(other.loginMethods) &&
          isSelfSignUpEnabled == other.isSelfSignUpEnabled &&
          isPasswordResetEnabled == other.isPasswordResetEnabled &&
          hasPasskey == other.hasPasskey &&
          passkeyMode == other.passkeyMode &&
          googleServerClientId == other.googleServerClientId &&
          facebookAppId == other.facebookAppId &&
          policyUri == other.policyUri &&
          tosUri == other.tosUri;

  @override
  int get hashCode => Object.hash(
    clientId,
    loginMethods.valuesHash,
    isSelfSignUpEnabled,
    isPasswordResetEnabled,
    hasPasskey,
    passkeyMode,
    googleServerClientId,
    facebookAppId,
    policyUri,
    tosUri,
  );
}
