import 'package:loginflow_auth/src/core/id_token/id_token_claims.dart';
import 'package:loginflow_auth/src/core/json/json_field_reader.dart';
import 'package:loginflow_auth/src/core/json/list_equality.dart';

/// Who is signed in, read from a validated ID token.
///
/// Key app data on ([companyId], [subject]); never on [email]
/// (OpenID Connect Core §2; `doc/decisions.md` D15).
class UserIdentity {
  const UserIdentity({
    required this.subject,
    this.companyId,
    this.sessionId,
    this.email,
    this.isEmailVerified = false,
    this.name,
    this.authTime,
    this.authenticationMethods = const <String>[],
    this.authenticationContext,
  });

  factory UserIdentity.fromClaims(IdTokenClaims claims) => UserIdentity(
    subject: claims.subject,
    companyId: claims.companyId,
    sessionId: claims.sessionId,
    email: claims.email,
    isEmailVerified: claims.isEmailVerified,
    name: claims.name,
    authTime: claims.authTime,
    authenticationMethods: claims.authenticationMethods,
    authenticationContext: claims.authenticationContext,
  );

  factory UserIdentity.fromJson(Map<String, Object?> json) {
    final authTime = json.optionalInt('auth_time');
    return UserIdentity(
      subject: json.requireString('sub'),
      companyId: json.optionalString('company_id'),
      sessionId: json.optionalString('sid'),
      email: json.optionalString('email'),
      isEmailVerified: json.optionalBool('email_verified', absent: false),
      name: json.optionalString('name'),
      authTime: authTime == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(authTime * 1000, isUtc: true),
      authenticationMethods: json.stringList('amr'),
      authenticationContext: json.optionalString('acr'),
    );
  }

  final String subject;
  final String? companyId;
  final String? sessionId;
  final String? email;
  final bool isEmailVerified;
  final String? name;
  final DateTime? authTime;
  final List<String> authenticationMethods;
  final String? authenticationContext;

  UserIdentity copyWith({
    String? subject,
    String? companyId,
    String? sessionId,
    String? email,
    bool? isEmailVerified,
    String? name,
    DateTime? authTime,
    List<String>? authenticationMethods,
    String? authenticationContext,
  }) => UserIdentity(
    subject: subject ?? this.subject,
    companyId: companyId ?? this.companyId,
    sessionId: sessionId ?? this.sessionId,
    email: email ?? this.email,
    isEmailVerified: isEmailVerified ?? this.isEmailVerified,
    name: name ?? this.name,
    authTime: authTime ?? this.authTime,
    authenticationMethods: authenticationMethods ?? this.authenticationMethods,
    authenticationContext: authenticationContext ?? this.authenticationContext,
  );

  Map<String, Object?> toJson() => <String, Object?>{
    'sub': subject,
    'company_id': ?companyId,
    'sid': ?sessionId,
    'email': ?email,
    'email_verified': isEmailVerified,
    'name': ?name,
    'auth_time': ?authTime.toEpochSeconds(),
    'amr': authenticationMethods,
    'acr': ?authenticationContext,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UserIdentity &&
          subject == other.subject &&
          companyId == other.companyId &&
          sessionId == other.sessionId &&
          email == other.email &&
          isEmailVerified == other.isEmailVerified &&
          name == other.name &&
          authTime == other.authTime &&
          authenticationMethods.hasSameValues(other.authenticationMethods) &&
          authenticationContext == other.authenticationContext;

  @override
  int get hashCode => Object.hash(
    subject,
    companyId,
    sessionId,
    email,
    isEmailVerified,
    name,
    authTime,
    authenticationMethods.valuesHash,
    authenticationContext,
  );
}

extension on DateTime? {
  int? toEpochSeconds() {
    final value = this;
    return value == null ? null : value.millisecondsSinceEpoch ~/ 1000;
  }
}
