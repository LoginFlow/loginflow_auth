import 'package:loginflow_auth/src/core/json/json_field_reader.dart';

/// Who a member is (`doc/server-contract.md` §18): the person's account in
/// this application.
class MemberIdentity {
  const MemberIdentity({
    required this.principalId,
    required this.email,
    this.name,
  });

  factory MemberIdentity.fromJson(Map<String, Object?> json) => MemberIdentity(
    principalId: json.requireString('principal_id'),
    email: json.requireString('email'),
    name: json.optionalString('name'),
  );

  /// The person's id in this application (the `sub` of their tokens): what
  /// `grantRole` takes.
  final String principalId;
  final String email;
  final String? name;

  MemberIdentity copyWith({String? principalId, String? email, String? name}) =>
      MemberIdentity(
        principalId: principalId ?? this.principalId,
        email: email ?? this.email,
        name: name ?? this.name,
      );

  Map<String, Object?> toJson() => <String, Object?>{
    'principal_id': principalId,
    'email': email,
    'name': name,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MemberIdentity &&
          principalId == other.principalId &&
          email == other.email &&
          name == other.name;

  @override
  int get hashCode => Object.hash(principalId, email, name);
}
