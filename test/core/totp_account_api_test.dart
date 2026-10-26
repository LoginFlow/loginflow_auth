import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:loginflow_auth/loginflow_auth_core.dart';

import '../support/auth_fixture.dart';
import '../support/fake_login_flow_server.dart';
import '../support/test_signing_keys.dart';

/// The signed-in person's authenticator app (`/v1/user/totp/*`,
/// `doc/server-contract.md` §20) against a fake LoginFlow that answers like
/// `totp_handler.rs` and `recovery_code_handler.rs`: the session's own
/// DPoP-bound token, `401 INVALID_CODE` for a wrong code, and the recent
/// sign-in the recovery codes need.
void main() {
  late TestSigningKeys keys;
  late FakeLoginFlowServer server;

  setUpAll(() => keys = TestSigningKeys.generate());

  setUp(() async {
    server = await FakeLoginFlowServer.start(keys);
    server.requiresDpop = true;
  });

  tearDown(() => server.close());

  Future<LoginFlowAuth> anaSignedIn() async {
    final fixture = AuthFixture.create(server, enableDpop: true);
    await fixture.auth.initialize();
    final signedIn = await fixture.auth.signInWithPassword(
      loginHint: 'ana@example.com',
      password: 'correct-horse',
    );
    expect(signedIn.data, isA<SignedIn>());
    return fixture.auth;
  }

  Map<String, Object?> lastBody() =>
      jsonDecode(server.totpRequests.last.body) as Map<String, Object?>;

  // TEST_CHARTER
  // Requirement: a person enrolls an authenticator app (setup, then a code
  // it produced turns it on), gets recovery codes, and turns it off again
  // with a current code; a wrong code is a typed refusal.
  // Oracle: the public `Result`s, the status LoginFlow reports after each
  // change, and the wire (paths, bodies, `DPoP` authorization).
  // Risk edge: `401 INVALID_CODE` read as an ended session or a generic
  // failure; the enrollment never turned on; the issuer not sent.
  // Layer: integration against the fake LoginFlow (real HTTP, real DPoP).
  // Counterfactual: mapping `401 INVALID_CODE` with `toAccountApiError`
  // turns the wrong-code refusal into `ServerResponseInvalid`; not sending
  // the confirmation leaves the status off.
  test('enroll, confirm, recovery codes and disable an authenticator app; '
      'a wrong code is InvalidTotpCode', () async {
    final auth = await anaSignedIn();

    final before = await auth.totpStatus();
    final enrollment = await auth.startTotpEnrollment(issuer: 'Kiwio Console');
    final setupBody = lastBody();
    final wrong = await auth.confirmTotpEnrollment('000000');
    final confirmed = await auth.confirmTotpEnrollment(
      FakeLoginFlowServer.totpCode,
    );
    final confirmBody = lastBody();
    final enabled = await auth.totpStatus();
    final codes = await auth.regenerateRecoveryCodes();
    final disabled = await auth.disableTotp(FakeLoginFlowServer.totpCode);
    final after = await auth.totpStatus();

    expect(before.data, const TotpStatus(isEnabled: false));
    expect(setupBody, <String, Object?>{'issuer': 'Kiwio Console'});
    expect(enrollment.data.secret, FakeLoginFlowServer.totpSecret);
    expect(enrollment.data.issuer, 'Kiwio Console');
    expect(
      enrollment.data.otpauthUri,
      startsWith('otpauth://totp/Kiwio%20Console:ana%40example.com?'),
    );
    expect(wrong.errorOrNull, const InvalidTotpCode());
    expect(confirmed.isOk, isTrue, reason: '$confirmed');
    expect(confirmBody, <String, Object?>{
      'code': FakeLoginFlowServer.totpCode,
    });
    expect(enabled.data.isEnabled, isTrue);
    expect(enabled.data.verifiedAt?.isUtc, isTrue);
    expect(codes.data, hasLength(10));
    expect(disabled.isOk, isTrue, reason: '$disabled');
    expect(after.data, const TotpStatus(isEnabled: false));
    expect(server.totpRequests.map((request) => request.uri.path), <String>[
      '/v1/user/totp/status',
      '/v1/user/totp/setup',
      '/v1/user/totp/verify-setup',
      '/v1/user/totp/verify-setup',
      '/v1/user/totp/status',
      '/v1/user/totp/recovery-codes',
      '/v1/user/totp/disable',
      '/v1/user/totp/status',
    ]);
    for (final request in server.totpRequests) {
      expect(request.headers['authorization'], startsWith('DPoP '));
      expect(request.headers['dpop'], isNotNull);
    }
  });

  // TEST_CHARTER
  // Requirement: recovery codes past the 300 s recent-auth window answer
  // `StepUpRequired` with the server's `max_age`, so the app can step up
  // and ask again.
  // Oracle: the public `Result` of `regenerateRecoveryCodes`.
  // Risk edge: the challenge lives only in `WWW-Authenticate`; the body is
  // the generic `UNAUTHORIZED` envelope.
  // Layer: integration against the fake LoginFlow.
  // Counterfactual: the first test asks with a recent sign-in and gets the
  // codes.
  test('recovery codes after a stale sign-in -> StepUpRequired', () async {
    final auth = await anaSignedIn();
    server.expireRecentAuthentications();

    final codes = await auth.regenerateRecoveryCodes();

    expect(
      codes.errorOrNull,
      const StepUpRequired(
        requirement: StepUpRequirement(maxAge: Duration(seconds: 300)),
      ),
    );
  });
}
