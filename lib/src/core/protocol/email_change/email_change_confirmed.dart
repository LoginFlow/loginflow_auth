import 'package:loginflow_auth/src/core/json/json_field_reader.dart';

/// The answer of `LoginFlowAuth.confirmEmailChange`
/// (`POST /v1/app/email-change/confirm`, `doc/server-contract.md` §19): the
/// account's email is now [email], verified. Every other session of the
/// person was ended; this one continues.
class EmailChangeConfirmed {
  /// Creates an [EmailChangeConfirmed].
  const EmailChangeConfirmed({
    required this.email,
    required this.isEmailVerified,
  });

  /// Reads an [EmailChangeConfirmed] from its JSON form ([toJson]).
  factory EmailChangeConfirmed.fromJson(Map<String, Object?> json) =>
      EmailChangeConfirmed(
        email: json.requireString('email'),
        isEmailVerified: json.requireBool('email_verified'),
      );

  /// The person's email from now on.
  final String email;

  /// Always `true`: the person proved they hold it.
  final bool isEmailVerified;

  /// A copy of this [EmailChangeConfirmed] with the given fields replaced.
  EmailChangeConfirmed copyWith({String? email, bool? isEmailVerified}) =>
      EmailChangeConfirmed(
        email: email ?? this.email,
        isEmailVerified: isEmailVerified ?? this.isEmailVerified,
      );

  /// The JSON form of this [EmailChangeConfirmed], read back by [EmailChangeConfirmed.fromJson].
  Map<String, Object?> toJson() => <String, Object?>{
    'email': email,
    'email_verified': isEmailVerified,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is EmailChangeConfirmed &&
          email == other.email &&
          isEmailVerified == other.isEmailVerified;

  @override
  int get hashCode => Object.hash(email, isEmailVerified);
}
