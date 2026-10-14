import 'package:loginflow_auth/src/core/json/json_field_reader.dart';
import 'package:loginflow_auth/src/core/json/list_equality.dart';
import 'package:loginflow_auth/src/sign_in/model/auth_method.dart';
import 'package:loginflow_auth/src/sign_in/model/sign_in_copy.dart';

/// What the built-in sign-in UI offers.
///
/// The UI renders [methods] in this order, intersected with what the server
/// enables for the client: a method the server does not allow is never
/// shown. With a single resulting method the UI opens it directly. A TOTP
/// step is shown automatically whenever the server asks for one.
class SignInConfiguration {
  const SignInConfiguration({
    required this.methods,
    this.isSelfSignUpOffered = false,
    this.copy = const SignInCopy(),
  });

  factory SignInConfiguration.fromJson(Map<String, Object?> json) {
    final rawMethods = json['methods'];
    if (rawMethods is! List<Object?>) {
      throw const FormatException('Field "methods" must be an array.');
    }
    final copy = json.optionalObject('copy');
    return SignInConfiguration(
      methods: List<AuthMethod>.unmodifiable(
        rawMethods.whereType<Map<String, Object?>>().map(AuthMethod.fromJson),
      ),
      isSelfSignUpOffered: json.optionalBool('self_signup', absent: false),
      copy: copy == null ? const SignInCopy() : SignInCopy.fromJson(copy),
    );
  }

  final List<AuthMethod> methods;

  /// "Create an account" is shown only if this is true AND the server
  /// enables self sign-up for the client.
  final bool isSelfSignUpOffered;
  final SignInCopy copy;

  SignInConfiguration copyWith({
    List<AuthMethod>? methods,
    bool? isSelfSignUpOffered,
    SignInCopy? copy,
  }) => SignInConfiguration(
    methods: methods ?? this.methods,
    isSelfSignUpOffered: isSelfSignUpOffered ?? this.isSelfSignUpOffered,
    copy: copy ?? this.copy,
  );

  Map<String, Object?> toJson() => <String, Object?>{
    'methods': methods.map((method) => method.toJson()).toList(),
    'self_signup': isSelfSignUpOffered,
    'copy': copy.toJson(),
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SignInConfiguration &&
          methods.hasSameValues(other.methods) &&
          isSelfSignUpOffered == other.isSelfSignUpOffered &&
          copy == other.copy;

  @override
  int get hashCode =>
      Object.hash(methods.valuesHash, isSelfSignUpOffered, copy);
}
