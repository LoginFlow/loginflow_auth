import 'package:loginflow_auth/src/core/json/json_field_reader.dart';
import 'package:loginflow_auth/src/core/json/list_equality.dart';
import 'package:loginflow_auth/src/core/session/access_subject_kind.dart';

/// The ID token claims the library reads (OpenID Connect Core §2, §5.1;
/// OpenID Connect Native SSO §3.4.1; LoginFlow `company_id` and the
/// access-code subject claims `ext_sub`/`subject_kind`/`ext_profile`,
/// `doc/server-contract.md` §16).
class IdTokenClaims {
  /// Creates an [IdTokenClaims].
  const IdTokenClaims({
    required this.issuer,
    required this.subject,
    required this.audiences,
    required this.expiresAt,
    required this.issuedAt,
    this.authTime,
    this.nonce,
    this.sessionId,
    this.authorizedParty,
    this.authenticationContext,
    this.authenticationMethods = const <String>[],
    this.deviceSecretHash,
    this.companyId,
    this.email,
    this.isEmailVerified = false,
    this.name,
    this.externalSubject,
    this.subjectKind,
    this.subjectProfile,
  });

  /// Reads an [IdTokenClaims] from its JSON form ([toJson]).
  factory IdTokenClaims.fromJson(Map<String, Object?> json) {
    final authTime = json.optionalInt('auth_time');
    final externalSubject = json.optionalString('ext_sub');
    final isAccessSubject = externalSubject != null;
    return IdTokenClaims(
      issuer: json.requireString('iss'),
      subject: json.requireString('sub'),
      audiences: json.stringOrStringList('aud'),
      expiresAt: _epoch(json.requireInt('exp')),
      issuedAt: _epoch(json.requireInt('iat')),
      authTime: authTime == null ? null : _epoch(authTime),
      nonce: json.optionalString('nonce'),
      sessionId: json.optionalString('sid'),
      authorizedParty: json.optionalString('azp'),
      authenticationContext: json.optionalString('acr'),
      authenticationMethods: json.stringList('amr'),
      deviceSecretHash: json.optionalString('ds_hash'),
      companyId: json.optionalString('company_id'),
      email: json.optionalString('email'),
      isEmailVerified: json.optionalBool('email_verified', absent: false),
      name: json.optionalString('name'),
      externalSubject: externalSubject,
      subjectKind: isAccessSubject
          ? AccessSubjectKind.fromWireName(json.optionalString('subject_kind'))
          : null,
      subjectProfile: isAccessSubject
          ? json.optionalString('ext_profile')
          : null,
    );
  }

  /// `iss`.
  final String issuer;

  /// `sub`: the stable identifier of the user, never the email.
  final String subject;

  /// `aud`, always as a list.
  final List<String> audiences;

  /// `exp`.
  final DateTime expiresAt;

  /// `iat`.
  final DateTime issuedAt;

  /// `auth_time`: when the user last authenticated.
  final DateTime? authTime;

  /// `nonce`, echoed from the authorization request.
  final String? nonce;

  /// `sid`: the device or browser session the token belongs to.
  final String? sessionId;

  /// `azp`.
  final String? authorizedParty;

  /// `acr`.
  final String? authenticationContext;

  /// `amr` (RFC 8176 values such as `pwd`, `otp`, `mfa`).
  final List<String> authenticationMethods;

  /// `ds_hash` (OpenID Connect Native SSO §3.4.1).
  final String? deviceSecretHash;

  /// LoginFlow tenant claim: the company the identity belongs to.
  final String? companyId;

  /// `email`, with the `email` scope.
  final String? email;

  /// `email_verified`.
  final bool isEmailVerified;

  /// `name`, with the `profile` scope.
  final String? name;

  /// `ext_sub`: the subject's id in the database of the tenant backend that
  /// issued its access code. Only access-code subjects carry it.
  final String? externalSubject;

  /// `subject_kind`, read only when [externalSubject] is present.
  final AccessSubjectKind? subjectKind;

  /// `ext_profile`: the issuer-defined profile label of an access-code
  /// subject (e.g. `Driver`, `Kiosk`), read only when [externalSubject] is
  /// present. Not the standard `profile` claim, which OpenID Connect Core
  /// §5.1 registers as a profile-page URL and which this library ignores.
  final String? subjectProfile;

  static DateTime _epoch(int seconds) =>
      DateTime.fromMillisecondsSinceEpoch(seconds * 1000, isUtc: true);

  static int _seconds(DateTime value) => value.millisecondsSinceEpoch ~/ 1000;

  /// A copy of this [IdTokenClaims] with the given fields replaced.
  IdTokenClaims copyWith({
    String? issuer,
    String? subject,
    List<String>? audiences,
    DateTime? expiresAt,
    DateTime? issuedAt,
    DateTime? authTime,
    String? nonce,
    String? sessionId,
    String? authorizedParty,
    String? authenticationContext,
    List<String>? authenticationMethods,
    String? deviceSecretHash,
    String? companyId,
    String? email,
    bool? isEmailVerified,
    String? name,
    String? externalSubject,
    AccessSubjectKind? subjectKind,
    String? subjectProfile,
  }) => IdTokenClaims(
    issuer: issuer ?? this.issuer,
    subject: subject ?? this.subject,
    audiences: audiences ?? this.audiences,
    expiresAt: expiresAt ?? this.expiresAt,
    issuedAt: issuedAt ?? this.issuedAt,
    authTime: authTime ?? this.authTime,
    nonce: nonce ?? this.nonce,
    sessionId: sessionId ?? this.sessionId,
    authorizedParty: authorizedParty ?? this.authorizedParty,
    authenticationContext: authenticationContext ?? this.authenticationContext,
    authenticationMethods: authenticationMethods ?? this.authenticationMethods,
    deviceSecretHash: deviceSecretHash ?? this.deviceSecretHash,
    companyId: companyId ?? this.companyId,
    email: email ?? this.email,
    isEmailVerified: isEmailVerified ?? this.isEmailVerified,
    name: name ?? this.name,
    externalSubject: externalSubject ?? this.externalSubject,
    subjectKind: subjectKind ?? this.subjectKind,
    subjectProfile: subjectProfile ?? this.subjectProfile,
  );

  /// The JSON form of this [IdTokenClaims], read back by [IdTokenClaims.fromJson].
  Map<String, Object?> toJson() => <String, Object?>{
    'iss': issuer,
    'sub': subject,
    'aud': audiences,
    'exp': _seconds(expiresAt),
    'iat': _seconds(issuedAt),
    'auth_time': ?authTime.toEpochSeconds(),
    'nonce': ?nonce,
    'sid': ?sessionId,
    'azp': ?authorizedParty,
    'acr': ?authenticationContext,
    if (authenticationMethods.isNotEmpty) 'amr': authenticationMethods,
    'ds_hash': ?deviceSecretHash,
    'company_id': ?companyId,
    'email': ?email,
    'email_verified': isEmailVerified,
    'name': ?name,
    'ext_sub': ?externalSubject,
    'subject_kind': ?subjectKind?.wireName,
    'ext_profile': ?subjectProfile,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is IdTokenClaims &&
          issuer == other.issuer &&
          subject == other.subject &&
          audiences.hasSameValues(other.audiences) &&
          expiresAt == other.expiresAt &&
          issuedAt == other.issuedAt &&
          authTime == other.authTime &&
          nonce == other.nonce &&
          sessionId == other.sessionId &&
          authorizedParty == other.authorizedParty &&
          authenticationContext == other.authenticationContext &&
          authenticationMethods.hasSameValues(other.authenticationMethods) &&
          deviceSecretHash == other.deviceSecretHash &&
          companyId == other.companyId &&
          email == other.email &&
          isEmailVerified == other.isEmailVerified &&
          name == other.name &&
          externalSubject == other.externalSubject &&
          subjectKind == other.subjectKind &&
          subjectProfile == other.subjectProfile;

  @override
  int get hashCode => Object.hash(
    issuer,
    subject,
    audiences.valuesHash,
    expiresAt,
    issuedAt,
    authTime,
    nonce,
    sessionId,
    authorizedParty,
    authenticationContext,
    authenticationMethods.valuesHash,
    deviceSecretHash,
    companyId,
    email,
    isEmailVerified,
    name,
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
