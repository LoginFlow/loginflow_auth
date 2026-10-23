/// The LoginFlow deployments an app can point at.
enum LoginFlowEnvironment {
  /// The production issuer.
  production('https://api.loginflow.dev'),

  /// The development issuer.
  development('https://api-dev.loginflow.dev');

  const LoginFlowEnvironment(this.issuerUrl);

  /// The issuer identifier, exactly as it appears in `iss` claims.
  final String issuerUrl;

  /// The issuer identifier of this environment, for `LoginFlowConfig.issuer`.
  Uri get issuer => Uri.parse(issuerUrl);
}
