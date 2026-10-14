import 'package:loginflow_auth/src/core/json/json_field_reader.dart';

/// The parameters of a redirect back from the authorization endpoint
/// (RFC 6749 §4.1.2 / §4.1.2.1, RFC 9207 §2).
class AuthorizationCallback {
  const AuthorizationCallback({
    this.code,
    this.state,
    this.issuer,
    this.error,
    this.errorDescription,
  });

  factory AuthorizationCallback.fromUri(Uri uri) {
    final query = uri.queryParameters;
    return AuthorizationCallback(
      code: query['code'],
      state: query['state'],
      issuer: query['iss'],
      error: query['error'],
      errorDescription: query['error_description'],
    );
  }

  factory AuthorizationCallback.fromJson(Map<String, Object?> json) =>
      AuthorizationCallback(
        code: json.optionalString('code'),
        state: json.optionalString('state'),
        issuer: json.optionalString('iss'),
        error: json.optionalString('error'),
        errorDescription: json.optionalString('error_description'),
      );

  /// `prompt=none` errors that mean "no usable browser session; ask
  /// interactively" (OpenID Connect Core §3.1.2.6).
  static const List<String> interactionErrors = <String>[
    'login_required',
    'interaction_required',
    'consent_required',
    'account_selection_required',
  ];

  final String? code;
  final String? state;
  final String? issuer;
  final String? error;
  final String? errorDescription;

  bool get requiresInteraction => interactionErrors.contains(error);

  AuthorizationCallback copyWith({
    String? code,
    String? state,
    String? issuer,
    String? error,
    String? errorDescription,
  }) => AuthorizationCallback(
    code: code ?? this.code,
    state: state ?? this.state,
    issuer: issuer ?? this.issuer,
    error: error ?? this.error,
    errorDescription: errorDescription ?? this.errorDescription,
  );

  Map<String, Object?> toJson() => <String, Object?>{
    'code': ?code,
    'state': ?state,
    'iss': ?issuer,
    'error': ?error,
    'error_description': ?errorDescription,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AuthorizationCallback &&
          code == other.code &&
          state == other.state &&
          issuer == other.issuer &&
          error == other.error &&
          errorDescription == other.errorDescription;

  @override
  int get hashCode => Object.hash(code, state, issuer, error, errorDescription);

  @override
  String toString() => 'AuthorizationCallback(error: $error)';
}
