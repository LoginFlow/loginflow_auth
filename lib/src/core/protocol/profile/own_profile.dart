import 'package:loginflow_auth/src/core/json/json_field_reader.dart';

/// What LoginFlow holds about the signed-in person
/// (`GET`/`PATCH /v1/app/profile`, `doc/server-contract.md` §24): their
/// email and names. Identity belongs to LoginFlow: a product reads the names
/// from here (or from the ID token) and keeps no name route of its own.
class OwnProfile {
  /// Creates an [OwnProfile].
  const OwnProfile({this.email, this.firstName, this.lastName, this.name});

  /// Reads an [OwnProfile] from its JSON form ([toJson]).
  factory OwnProfile.fromJson(Map<String, Object?> json) => OwnProfile(
    email: json.optionalString('email'),
    firstName: json.optionalString('first_name'),
    lastName: json.optionalString('last_name'),
    name: json.optionalString('name'),
  );

  /// The person's email; `null` for a passkey-only account, until they add
  /// one with `LoginFlowAuth.startEmailChange`.
  final String? email;

  /// The first name, when known.
  final String? firstName;

  /// The last name, when known.
  final String? lastName;

  /// The names joined, as the ID token's `name`; `null` when neither is
  /// known.
  final String? name;

  /// A copy of this [OwnProfile] with the given fields replaced.
  OwnProfile copyWith({
    String? email,
    String? firstName,
    String? lastName,
    String? name,
  }) => OwnProfile(
    email: email ?? this.email,
    firstName: firstName ?? this.firstName,
    lastName: lastName ?? this.lastName,
    name: name ?? this.name,
  );

  /// The JSON form of this [OwnProfile], read back by [OwnProfile.fromJson].
  Map<String, Object?> toJson() => <String, Object?>{
    'email': email,
    'first_name': firstName,
    'last_name': lastName,
    'name': name,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is OwnProfile &&
          email == other.email &&
          firstName == other.firstName &&
          lastName == other.lastName &&
          name == other.name;

  @override
  int get hashCode => Object.hash(email, firstName, lastName, name);
}
