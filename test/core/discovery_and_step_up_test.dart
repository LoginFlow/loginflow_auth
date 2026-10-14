import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:loginflow_auth/loginflow_auth_core.dart';

void main() {
  group('Discovery', () {
    var requestCount = 0;

    setUp(() => requestCount = 0);

    LoginFlowAuth authAgainst(
      Map<String, Object?> Function() document, {
      Uri? issuer,
    }) => LoginFlowAuth(
      config: LoginFlowConfig(
        issuer: issuer ?? LoginFlowEnvironment.production.issuer,
        clientId: 'app-one',
      ),
      httpClient: MockClient((request) async {
        requestCount++;
        return http.Response.bytes(
          utf8.encode(jsonEncode(document())),
          200,
          headers: <String, String>{'content-type': 'application/json'},
        );
      }),
      sessionStore: InMemorySessionStore(),
      pendingAuthorizationStore: InMemoryPendingAuthorizationStore(),
    );

    Map<String, Object?> document({
      String issuer = 'https://api.loginflow.dev',
      List<String> pkce = const <String>['S256'],
      String tokenEndpoint = 'https://api.loginflow.dev/oauth2/token',
      bool isIssuerParameterSupported = true,
    }) => <String, Object?>{
      'authorization_response_iss_parameter_supported':
          isIssuerParameterSupported,
      'issuer': issuer,
      'authorization_endpoint': 'https://api.loginflow.dev/oauth2/authorize',
      'token_endpoint': tokenEndpoint,
      'jwks_uri': 'https://api.loginflow.dev/oauth2/jwks',
      'id_token_signing_alg_values_supported': <String>['RS256'],
      'code_challenge_methods_supported': pkce,
    };

    test('a document for another issuer is refused (Discovery §4.3)', () async {
      final auth = authAgainst(() => document(issuer: 'https://evil.example'));

      final result = await auth.fetchLoginOptions();

      expect(result.errorOrNull, isA<DiscoveryInvalid>());
    });

    test('a server without S256 is refused (RFC 9700 §2.1.1)', () async {
      final auth = authAgainst(() => document(pkce: const <String>['plain']));

      final result = await auth.fetchLoginOptions();

      expect(result.errorOrNull, isA<DiscoveryInvalid>());
    });

    test('a non-TLS endpoint is refused', () async {
      final auth = authAgainst(
        () => document(tokenEndpoint: 'http://api.loginflow.dev/oauth2/token'),
      );

      final result = await auth.fetchLoginOptions();

      expect(result.errorOrNull, isA<DiscoveryInvalid>());
    });

    test('a server without the iss response parameter is refused '
        '(RFC 9207 §2.4)', () async {
      final auth = authAgainst(
        () => document(isIssuerParameterSupported: false),
      );

      final result = await auth.fetchLoginOptions();

      expect(result.errorOrNull, isA<DiscoveryInvalid>());
    });

    test('a non-TLS issuer is refused before any request', () async {
      final auth = authAgainst(
        () => document(issuer: 'http://api.loginflow.dev'),
        issuer: Uri.parse('http://api.loginflow.dev'),
      );

      final result = await auth.fetchLoginOptions();

      expect(result.errorOrNull, isA<DiscoveryInvalid>());
      expect(requestCount, 0);
    });

    test('LoginFlowConfig.validate refuses insecure or malformed URIs', () {
      LoginFlowError? problemOf(LoginFlowConfig config) =>
          config.validate().errorOrNull;
      final valid = LoginFlowConfig(
        issuer: LoginFlowEnvironment.production.issuer,
        clientId: 'app-one',
        redirectUri: Uri.parse('com.acme.orders:/oauth/callback'),
      );

      expect(problemOf(valid), isNull);
      expect(
        problemOf(
          valid.copyWith(issuer: Uri.parse('http://api.loginflow.dev')),
        ),
        isA<ConfigurationInvalid>(),
      );
      expect(
        problemOf(
          valid.copyWith(issuer: Uri.parse('https://api.loginflow.dev?x=1')),
        ),
        isA<ConfigurationInvalid>(),
      );
      expect(
        problemOf(
          valid.copyWith(redirectUri: Uri.parse('https://acme.example/cb#x')),
        ),
        isA<ConfigurationInvalid>(),
      );
      expect(
        problemOf(valid.copyWith(redirectUri: Uri.parse('myapp:/callback'))),
        isA<ConfigurationInvalid>(),
      );
      expect(
        problemOf(
          valid.copyWith(redirectUri: Uri.parse('http://acme.example/cb')),
        ),
        isA<ConfigurationInvalid>(),
      );
    });

    test('a missing extension endpoint is reported, not guessed', () async {
      final auth = authAgainst(document);

      final result = await auth.fetchLoginOptions();

      expect(
        result.errorOrNull,
        const UnsupportedByServer(feature: 'loginflow_login_options_endpoint'),
      );
    });
  });

  group('StepUpRequirement.fromWwwAuthenticate (RFC 9470 §3)', () {
    test('reads acr_values and max_age', () {
      final requirement = StepUpRequirement.fromWwwAuthenticate(
        'Bearer error="insufficient_user_authentication", '
        'error_description="A different authentication level is required", '
        'acr_values="mfa phr", max_age=300',
      );

      expect(
        requirement,
        const StepUpRequirement(
          acrValues: <String>['mfa', 'phr'],
          maxAge: Duration(seconds: 300),
        ),
      );
    });

    test('ignores other Bearer errors', () {
      expect(
        StepUpRequirement.fromWwwAuthenticate('Bearer error="invalid_token"'),
        isNull,
      );
    });
  });
}
