import 'package:loginflow_auth/src/core/json/json_field_reader.dart';
import 'package:loginflow_auth/src/core/json/list_equality.dart';

/// What the server allows for this client: the primary login methods, and
/// whether self sign-up and password reset are enabled (LoginFlow extension
/// `loginflow_login_options_endpoint`, see `doc/server-contract.md`).
class ClientLoginOptions {
  const ClientLoginOptions({
    required this.clientId,
    required this.loginMethods,
    required this.isSelfSignUpEnabled,
    required this.isPasswordResetEnabled,
  });

  factory ClientLoginOptions.fromJson(Map<String, Object?> json) =>
      ClientLoginOptions(
        clientId: json.requireString('client_id'),
        loginMethods: json.stringList('login_methods'),
        isSelfSignUpEnabled: json.optionalBool('self_signup', absent: false),
        isPasswordResetEnabled: json.optionalBool(
          'password_reset',
          absent: false,
        ),
      );

  final String clientId;

  /// Wire names: `password`, `email_otp`, `google`, `microsoft`. Unknown
  /// names are kept so newer server methods are simply not matched.
  final List<String> loginMethods;
  final bool isSelfSignUpEnabled;
  final bool isPasswordResetEnabled;

  bool allows(String methodWireName) => loginMethods.contains(methodWireName);

  ClientLoginOptions copyWith({
    String? clientId,
    List<String>? loginMethods,
    bool? isSelfSignUpEnabled,
    bool? isPasswordResetEnabled,
  }) => ClientLoginOptions(
    clientId: clientId ?? this.clientId,
    loginMethods: loginMethods ?? this.loginMethods,
    isSelfSignUpEnabled: isSelfSignUpEnabled ?? this.isSelfSignUpEnabled,
    isPasswordResetEnabled:
        isPasswordResetEnabled ?? this.isPasswordResetEnabled,
  );

  Map<String, Object?> toJson() => <String, Object?>{
    'client_id': clientId,
    'login_methods': loginMethods,
    'self_signup': isSelfSignUpEnabled,
    'password_reset': isPasswordResetEnabled,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ClientLoginOptions &&
          clientId == other.clientId &&
          loginMethods.hasSameValues(other.loginMethods) &&
          isSelfSignUpEnabled == other.isSelfSignUpEnabled &&
          isPasswordResetEnabled == other.isPasswordResetEnabled;

  @override
  int get hashCode => Object.hash(
    clientId,
    loginMethods.valuesHash,
    isSelfSignUpEnabled,
    isPasswordResetEnabled,
  );
}
