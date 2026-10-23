import 'package:loginflow_auth/src/core/login_flow_auth.dart';
import 'package:loginflow_auth/src/sign_in/model/sign_in_configuration.dart';
import 'package:loginflow_auth/src/sign_in/model/sign_in_environment.dart';
import 'package:loginflow_auth/src/sign_in/service/sign_in_service.dart';

/// Composition root of the sign-in UI: call [install] once at start-up,
/// after creating the [LoginFlowAuth].
abstract final class LoginFlowSignInSetup {
  /// Installs the sign-in UI over [auth] with [configuration]: call it once
  /// at start-up, before showing `LoginFlowSignIn` or `LoginFlowPasskeys`.
  static void install({
    required LoginFlowAuth auth,
    required SignInConfiguration configuration,
  }) => SignInService.environment.updateState(
    SignInEnvironment(auth: auth, configuration: configuration),
  );
}
