import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:loginflow_auth/loginflow_auth_core.dart';
import 'package:loginflow_auth/src/core/http/login_flow_transport.dart';
import 'package:loginflow_auth/src/core/id_token/id_token_expectations.dart';
import 'package:loginflow_auth/src/core/id_token/id_token_validator.dart';
import 'package:loginflow_auth/src/core/jose/jwks_cache.dart';

import '../support/test_clock.dart';
import '../support/test_signing_keys.dart';

void main() {
  const issuer = 'https://api.loginflow.dev';
  late TestSigningKeys keys;
  late TestClock clock;
  late Map<String, Object?> publishedKeys;
  late int jwksDownloads;
  late IdTokenValidator validator;

  final discovery = DiscoveryDocument(
    issuer: issuer,
    authorizationEndpoint: Uri.parse('$issuer/oauth2/authorize'),
    tokenEndpoint: Uri.parse('$issuer/oauth2/token'),
    jwksUri: Uri.parse('$issuer/oauth2/jwks'),
    idTokenSigningAlgorithms: const <String>['RS256', 'ES256'],
    codeChallengeMethods: const <String>['S256'],
    isIssuerParameterSupported: true,
  );
  const expectations = IdTokenExpectations.forClient(clientId: 'app-one');

  setUpAll(() => keys = TestSigningKeys.generate());

  setUp(() {
    clock = TestClock();
    publishedKeys = keys.jwks;
    jwksDownloads = 0;
    final transport = LoginFlowTransport(
      client: MockClient((request) async {
        jwksDownloads++;
        return http.Response(jsonEncode(publishedKeys), 200);
      }),
      timeout: const Duration(seconds: 5),
    );
    validator = IdTokenValidator(
      jwks: JwksCache(transport: transport, clock: clock),
      clock: clock,
      clockSkew: const Duration(seconds: 60),
    );
  });

  Map<String, Object?> claims({
    Object audience = 'app-one',
    String? authorizedParty,
    Duration issuedIn = Duration.zero,
  }) {
    final now = clock.now().millisecondsSinceEpoch ~/ 1000;
    return <String, Object?>{
      'iss': issuer,
      'sub': 'cu_ana',
      'aud': audience,
      'exp': now + 3600,
      'iat': now + issuedIn.inSeconds,
      'azp': ?authorizedParty,
    };
  }

  Future<IdTokenFailure?> failureOf(String token) async =>
      switch ((await validator.validate(
        token,
        discovery: discovery,
        expectations: expectations,
      )).errorOrNull) {
        IdTokenRejected(:final reason) => reason,
        _ => null,
      };

  test(
    'HS256 (algorithm confusion with the RSA public key) is refused',
    () async {
      expect(
        await failureOf(keys.sign(claims(), algorithm: 'HS256')),
        IdTokenFailure.unsupportedAlgorithm,
      );
    },
  );

  test('several audiences need azp = this client', () async {
    final audiences = <String>['app-one', 'app-two'];

    expect(
      await failureOf(keys.sign(claims(audience: audiences))),
      IdTokenFailure.authorizedPartyMismatch,
    );
    expect(
      await failureOf(
        keys.sign(claims(audience: audiences, authorizedParty: 'app-two')),
      ),
      IdTokenFailure.authorizedPartyMismatch,
    );
    expect(
      await failureOf(
        keys.sign(claims(audience: audiences, authorizedParty: 'app-one')),
      ),
      isNull,
    );
  });

  test('iat in the future beyond the skew is refused', () async {
    expect(
      await failureOf(keys.sign(claims(issuedIn: const Duration(minutes: 5)))),
      IdTokenFailure.issuedInFuture,
    );
  });

  test('a token without kid is refused', () async {
    expect(
      await failureOf(keys.sign(claims(), omitsKeyId: true)),
      IdTokenFailure.unknownKey,
    );
  });

  test('a crit header is refused', () async {
    expect(
      await failureOf(
        keys.sign(
          claims(),
          extraHeader: <String, Object?>{
            'crit': <String>['exp'],
          },
        ),
      ),
      IdTokenFailure.criticalHeader,
    );
  });

  test('an unknown kid refetches the JWKS at most once a minute', () async {
    publishedKeys = keys.rsaOnlyJwks;
    expect(await failureOf(keys.sign(claims())), isNull);
    expect(jwksDownloads, 1);

    publishedKeys = keys.jwks;
    final rotated = keys.sign(claims(), algorithm: 'ES256');
    expect(await failureOf(rotated), IdTokenFailure.unknownKey);
    expect(jwksDownloads, 1);

    clock.advance(const Duration(seconds: 61));
    expect(await failureOf(rotated), isNull);
    expect(jwksDownloads, 2);
  });

  test('concurrent validations share one JWKS download', () async {
    final token = keys.sign(claims());

    await Future.wait(<Future<IdTokenFailure?>>[
      failureOf(token),
      failureOf(token),
      failureOf(token),
    ]);

    expect(jwksDownloads, 1);
  });
}
