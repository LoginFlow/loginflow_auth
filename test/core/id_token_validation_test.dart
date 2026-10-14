import 'package:flutter_test/flutter_test.dart';
import 'package:loginflow_auth/loginflow_auth_core.dart';

import '../support/auth_fixture.dart';
import '../support/fake_login_flow_server.dart';
import '../support/test_signing_keys.dart';

void main() {
  late TestSigningKeys keys;
  late FakeLoginFlowServer server;

  setUpAll(() => keys = TestSigningKeys.generate());

  setUp(() async => server = await FakeLoginFlowServer.start(keys));

  tearDown(() => server.close());

  Future<Result<AuthState, LoginFlowError>> signIn(AuthFixture fixture) async {
    await fixture.auth.initialize();
    return fixture.auth.signInWithPassword(
      loginHint: 'ana@example.com',
      password: 'correct-horse',
    );
  }

  group('ID token validation (OpenID Connect Core §3.1.3.7)', () {
    final cases = <IdTokenTampering, IdTokenFailure>{
      IdTokenTampering.wrongIssuer: IdTokenFailure.issuerMismatch,
      IdTokenTampering.wrongAudience: IdTokenFailure.audienceMismatch,
      IdTokenTampering.wrongNonce: IdTokenFailure.nonceMismatch,
      IdTokenTampering.badSignature: IdTokenFailure.invalidSignature,
      IdTokenTampering.expired: IdTokenFailure.expired,
      IdTokenTampering.algorithmNone: IdTokenFailure.unsupportedAlgorithm,
      IdTokenTampering.accessTokenType: IdTokenFailure.wrongTokenType,
    };

    for (final MapEntry(key: tampering, value: failure) in cases.entries) {
      test('${tampering.name} is rejected as ${failure.name}', () async {
        server.tampering = tampering;
        final fixture = AuthFixture.create(server);

        final result = await signIn(fixture);

        expect(result.errorOrNull, IdTokenRejected(reason: failure));
        expect(fixture.auth.state, const SignedOut());
        expect(await fixture.storedSession(), isNull);
        expect(
          (await fixture.auth.accessToken()).errorOrNull,
          const NotSignedIn(),
        );
      });
    }

    test('ES256 ID tokens verify against the EC key of the JWKS', () async {
      server.idTokenAlgorithm = 'ES256';
      final fixture = AuthFixture.create(server);

      final result = await signIn(fixture);

      expect(result.data, isA<SignedIn>());
    });
  });
}
