import 'package:loginflow_auth/src/core/login_flow_auth.dart';
import 'package:loginflow_auth/src/sign_in/model/sign_in_configuration.dart';

/// The client and configuration the sign-in UI works with, installed once
/// by the app (`LoginFlowSignInSetup.install`).
///
/// It holds a live [LoginFlowAuth], so it is never serialized and has no
/// `toJson`/`fromJson`; equality is by client identity and configuration.
class SignInEnvironment {
  const SignInEnvironment({required this.auth, required this.configuration});

  const SignInEnvironment.notInstalled()
    : auth = null,
      configuration = const SignInConfiguration(methods: []);

  final LoginFlowAuth? auth;
  final SignInConfiguration configuration;

  SignInEnvironment copyWith({
    LoginFlowAuth? auth,
    SignInConfiguration? configuration,
  }) => SignInEnvironment(
    auth: auth ?? this.auth,
    configuration: configuration ?? this.configuration,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SignInEnvironment &&
          identical(auth, other.auth) &&
          configuration == other.configuration;

  @override
  int get hashCode => Object.hash(identityHashCode(auth), configuration);
}
