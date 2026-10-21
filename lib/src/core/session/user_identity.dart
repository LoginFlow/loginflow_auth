import 'package:loginflow_auth/src/core/id_token/id_token_claims.dart';
import 'package:loginflow_auth/src/core/json/json_field_reader.dart';
import 'package:loginflow_auth/src/core/json/list_equality.dart';
import 'package:loginflow_auth/src/core/session/access_subject_kind.dart';

/// Who is signed in, read from a validated ID token.
///
/// Key app data on ([companyId], [subject]); never on [email]
/// (OpenID Connect Core §2; `doc/decisions.md` D15).
///
/// A subject signed in with an access code (`LoginFlowAuth.signInWithAccessCode`)
/// also carries [externalSubject], [subjectKind] and [subjectProfile]; LoginFlow
/// keeps no personal data for it, so [email] and [name] are usually `null`.
/// All three are `null` for a regular user.
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
    this.externalSubject,
    this.subjectKind,
    this.subjectProfile,
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
    externalSubject: claims.externalSubject,
    subjectKind: claims.subjectKind,
    subjectProfile: claims.subjectProfile,
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
      externalSubject: json.optionalString('ext_sub'),
      subjectKind: AccessSubjectKind.fromWireName(
        json.optionalString('subject_kind'),
      ),
      subjectProfile: json.optionalString('ext_profile'),
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

  /// The subject's id in the tenant backend that issued its access code
  /// (`ext_sub`): key the app's own data on it.
  final String? externalSubject;

  /// Whether the access-code subject is a person or a shared device
  /// (`subject_kind`).
  final AccessSubjectKind? subjectKind;

  /// The issuer-defined profile label of the access-code subject (e.g.
  /// `Driver`, `Kiosk`), from the `ext_profile` claim. Not the OpenID Connect
  /// `profile` claim (a profile-page URL).
  final String? subjectProfile;

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
    String? externalSubject,
    AccessSubjectKind? subjectKind,
    String? subjectProfile,
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
    externalSubject: externalSubject ?? this.externalSubject,
    subjectKind: subjectKind ?? this.subjectKind,
    subjectProfile: subjectProfile ?? this.subjectProfile,
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
    'ext_sub': ?externalSubject,
    'subject_kind': ?subjectKind?.wireName,
    'ext_profile': ?subjectProfile,
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
          authenticationContext == other.authenticationContext &&
          externalSubject == other.externalSubject &&
          subjectKind == other.subjectKind &&
          subjectProfile == other.subjectProfile;

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
    externalSubject,
    subjectKind,
    subjectProfile,
  );
}

extension on DateTime? {
  int? toEpochSeconds() {
    final value = this;
    return value == null ? null : value.millisecondsSinceEpoch ~/ 1000;
  }
}
