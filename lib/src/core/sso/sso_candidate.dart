import 'package:loginflow_auth/src/core/json/json_field_reader.dart';

/// The account another app of the same publisher already signed in, shown as
/// "Continue as …" before Native SSO is used. The confirmation exists because
/// Native SSO does not prove the same human is holding the device (OpenID
/// Connect Native SSO §6.4, `doc/decisions.md` D13).
class SsoCandidate {
  /// Creates a [SsoCandidate].
  const SsoCandidate({
    required this.subject,
    this.name,
    this.email,
    this.companyId,
  });

  /// Reads a [SsoCandidate] from its JSON form ([toJson]).
  factory SsoCandidate.fromJson(Map<String, Object?> json) => SsoCandidate(
    subject: json.requireString('sub'),
    name: json.optionalString('name'),
    email: json.optionalString('email'),
    companyId: json.optionalString('company_id'),
  );

  /// `sub` of the shared session's user.
  final String subject;

  /// The user's name, for "Continue as …".
  final String? name;

  /// The user's email, for "Continue as …".
  final String? email;

  /// The company of the user.
  final String? companyId;

  /// A copy of this [SsoCandidate] with the given fields replaced.
  SsoCandidate copyWith({
    String? subject,
    String? name,
    String? email,
    String? companyId,
  }) => SsoCandidate(
    subject: subject ?? this.subject,
    name: name ?? this.name,
    email: email ?? this.email,
    companyId: companyId ?? this.companyId,
  );

  /// The JSON form of this [SsoCandidate], read back by [SsoCandidate.fromJson].
  Map<String, Object?> toJson() => <String, Object?>{
    'sub': subject,
    'name': ?name,
    'email': ?email,
    'company_id': ?companyId,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SsoCandidate &&
          subject == other.subject &&
          name == other.name &&
          email == other.email &&
          companyId == other.companyId;

  @override
  int get hashCode => Object.hash(subject, name, email, companyId);
}
