import 'package:flutter_test/flutter_test.dart';

import '../support/auth_fixture.dart';
import '../support/fake_login_flow_server.dart';
import '../support/test_signing_keys.dart';

void main() {
  late TestSigningKeys keys;
  late FakeLoginFlowServer server;

  setUpAll(() => keys = TestSigningKeys.generate());

  setUp(() async => server = await FakeLoginFlowServer.start(keys));

  tearDown(() => server.close());

  group('LoginFlowAuth.magicLinkTokenFromUri', () {
    test('returns the token of a link addressed to this app', () {
      final auth = AuthFixture.create(server, clientId: 'app-one').auth;

      final token = auth.magicLinkTokenFromUri(
        Uri.parse(
          'https://acme.id.loginflow.dev/login/magic/app-one?token=abc123',
        ),
      );

      expect(token, 'abc123');
    });

    test('ignores a link addressed to another app of the same company', () {
      final auth = AuthFixture.create(server, clientId: 'app-one').auth;

      final token = auth.magicLinkTokenFromUri(
        Uri.parse(
          'https://acme.id.loginflow.dev/login/magic/app-two?token=abc123',
        ),
      );

      expect(token, isNull);
    });

    test('ignores a non-https link, an extra path segment and a missing token', () {
      final auth = AuthFixture.create(server, clientId: 'app-one').auth;

      expect(
        auth.magicLinkTokenFromUri(
          Uri.parse(
            'http://acme.id.loginflow.dev/login/magic/app-one?token=abc123',
          ),
        ),
        isNull,
      );
      expect(
        auth.magicLinkTokenFromUri(
          Uri.parse(
            'https://acme.id.loginflow.dev/login/magic/app-one/x?token=abc123',
          ),
        ),
        isNull,
      );
      expect(
        auth.magicLinkTokenFromUri(
          Uri.parse('https://acme.id.loginflow.dev/login/magic/app-one'),
        ),
        isNull,
      );
    });
  });
}
