/// The LoginFlow deployments an app can point at.
enum LoginFlowEnvironment {
  production('https://api.loginflow.dev'),
  development('https://api-dev.loginflow.dev');

  const LoginFlowEnvironment(this.issuerUrl);

  /// The issuer identifier, exactly as it appears in `iss` claims.
  final String issuerUrl;

  Uri get issuer => Uri.parse(issuerUrl);
}
