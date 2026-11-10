// TEST_CHARTER
// Requirement: the approver side of the sign-in by QR (`device_qr`,
// `doc/server-contract.md` §21). `parseSignInQr` accepts only
// `https://<LoginFlowConfig.passkeyRpId>/qr/<uuid>#<secret>` and refuses a
// QR of another company before any request; `signInQrDetails`,
// `approveQrSignIn` and `denyQrSignIn` send the secret only in the JSON
// body; the approval needs a passkey within 120 s, so the library runs the
// passkey step-up itself (before the call for a session that is not a
// recent passkey, or once after the server's RFC 9470 challenge) and sends
// the approval once more.
// Oracle: the public `Result`s, the QR's final status on the fake server,
// the device-QR requests it received (URL without the secret, JSON body
// with it) and the passkey step-up openings it saw.
// Risk edge: a foreign host must never reach the network; the step-up must
// be the passkey one and the retry exactly one; an expired QR is a typed
// refusal, not a generic error.
// Layer: core, through `LoginFlowAuth` and the real transport against the
// fake server's HTTP dispatch.
// Counterfactual: without the host check the foreign QR parses; without
// `_withRecentPasskey` the password session gets `StepUpRequired`; without
// the `device_qr_*` mapping the expired QR is `ServerResponseInvalid`.

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:loginflow_auth/loginflow_auth_core.dart';

import '../support/auth_fixture.dart';
import '../support/fake_login_flow_server.dart';
import '../support/fake_passkey_authenticator.dart';
import '../support/test_signing_keys.dart';

void main() {
  late TestSigningKeys keys;
  late FakeLoginFlowServer server;

  setUpAll(() => keys = TestSigningKeys.generate());

  setUp(() async {
    server = await FakeLoginFlowServer.start(keys);
    server.loginMethods = <String>[...server.loginMethods, 'passkey'];
  });

  tearDown(() => server.close());

  Future<AuthFixture> signedInWithPassword() async {
    final fixture = AuthFixture.create(
      server,
      passkey: FakePasskeyAuthenticator(),
    );
    await fixture.auth.initialize();
    final signedIn = await fixture.auth.signInWithPassword(
      loginHint: 'ana@example.com',
      password: 'correct-horse',
    );
    expect(signedIn.data, isA<SignedIn>());
    return fixture;
  }

  Future<AuthFixture> signedInWithPasskey() async {
    final fixture = AuthFixture.create(
      server,
      passkey: FakePasskeyAuthenticator(),
    );
    await fixture.auth.initialize();
    final signedIn = await fixture.auth.signInWithPasskey(
      loginHint: 'ana@example.com',
    );
    expect(signedIn.data, isA<SignedIn>());
    return fixture;
  }

  List<FakeHttpRequest> approvalCalls() => server.deviceQrRequests
      .where((request) => request.uri.path.endsWith('/approve'))
      .toList();

  List<Map<String, String>> passkeyStepUpOpenings() => server.challengeRequests
      .where(
        (form) =>
            form['acr_values'] == LoginFlowAuth.phishingResistantAcr &&
            form['max_age'] == '120',
      )
      .toList();

  group('parseSignInQr', () {
    test(
      'reads the request id and the secret of a QR of its company',
      () async {
        final fixture = AuthFixture.create(server);
        final qr = server.showQrSignIn();

        final parsed = await fixture.auth.parseSignInQr(qr.uri);

        expect(
          parsed.data,
          SignInQr(requestId: qr.requestId, secret: qr.secret),
        );
        expect(parsed.data.toString(), isNot(contains(qr.secret)));
      },
    );

    test('a QR of another company is refused and never sent', () async {
      final fixture = await signedInWithPassword();
      final qr = server.showQrSignIn();
      final foreign = qr.uri.replaceFirst(
        FakeLoginFlowServer.passkeyRpId,
        'evil-id.loginflow.dev',
      );

      final parsed = await fixture.auth.parseSignInQr(foreign);

      expect(
        parsed.errorOrNull,
        const InvalidSignInQr(problem: SignInQrProblem.otherCompany),
      );
      expect(server.deviceQrRequests, isEmpty);
    });

    test('anything else is malformed', () async {
      final fixture = AuthFixture.create(server);
      final qr = server.showQrSignIn();
      const malformed = InvalidSignInQr(problem: SignInQrProblem.malformed);

      expect(
        (await fixture.auth.parseSignInQr(qr.uri.replaceFirst('https', 'http')))
            .errorOrNull,
        malformed,
      );
      expect(
        (await fixture.auth.parseSignInQr(qr.uri.split('#').first)).errorOrNull,
        malformed,
      );
      expect(
        (await fixture.auth.parseSignInQr('https://example.com/menu'))
            .errorOrNull,
        malformed,
      );
    });

    // TEST_CHARTER (tdd-light)
    // Requirement: an app that did not configure `passkeyRpId` checks a
    // scanned QR against the `passkey_rp_id` LoginFlow publishes in
    // `GET /oauth2/login-options`; the configured value keeps priority.
    // Oracle: the `Result` of `parseSignInQr` — accepted for the published
    // host, `otherCompany` for another one, `notConfigured` when neither
    // the app nor the server names a host; with a configured host, a
    // different published host changes nothing.
    // Risk edge: the fallback reading the wrong field, or the server value
    // overriding the app's own configuration.
    // Layer: core against the fake LoginFlow server (real HTTP).
    // Counterfactual: without the fallback the first expectation is
    // `notConfigured`; preferring the published value turns the last one
    // into `otherCompany`.
    test('without its own passkey host the app uses the one LoginFlow '
        'publishes, and its own host wins when it has one', () async {
      final unconfigured = AuthFixture.create(server, knowsPasskeyRpId: false);
      final qr = server.showQrSignIn();

      expect(
        (await unconfigured.auth.parseSignInQr(qr.uri)).data,
        SignInQr(requestId: qr.requestId, secret: qr.secret),
      );
      expect(
        (await unconfigured.auth.parseSignInQr(
          qr.uri.replaceFirst(
            FakeLoginFlowServer.passkeyRpId,
            'evil-id.loginflow.dev',
          ),
        )).errorOrNull,
        const InvalidSignInQr(problem: SignInQrProblem.otherCompany),
      );

      server.publishedPasskeyRpId = null;
      expect(
        (await unconfigured.auth.parseSignInQr(qr.uri)).errorOrNull,
        const InvalidSignInQr(problem: SignInQrProblem.notConfigured),
      );

      server.publishedPasskeyRpId = 'other-id.loginflow.dev';
      final configured = AuthFixture.create(server);
      expect((await configured.auth.parseSignInQr(qr.uri)).isOk, isTrue);
    });

    test('a failed login-options read is returned as is', () async {
      final unconfigured = AuthFixture.create(server, knowsPasskeyRpId: false);
      final qr = server.showQrSignIn();
      server.isLoginOptionsDown = true;

      final parsed = await unconfigured.auth.parseSignInQr(qr.uri);

      expect(parsed.errorOrNull, isNot(isA<InvalidSignInQr>()));
      expect(parsed.isOk, isFalse);
    });
  });

  test('details are typed, with UTC timestamps; the secret travels only in '
      'the JSON body', () async {
    final fixture = await signedInWithPassword();
    final qr = server.showQrSignIn();
    final scanned = (await fixture.auth.parseSignInQr(qr.uri)).data;

    final details = await fixture.auth.signInQrDetails(scanned);

    expect(
      details.data,
      SignInQrDetails(
        requestId: qr.requestId,
        clientId: 'panel-web',
        clientName: 'Payments panel',
        applicationId: FakeLoginFlowServer.applicationId,
        requester: const PhoneApprovalRequester(
          device: 'Chrome on macOS',
          ipAddress: '203.0.113.7',
        ),
        createdAt: details.data.createdAt,
        expiresAt: details.data.expiresAt,
      ),
    );
    expect(details.data.expiresAt.isUtc, isTrue);
    expect(SignInQrDetails.fromJson(details.data.toJson()), details.data);
    final request = server.deviceQrRequests.single;
    expect(request.uri.toString(), isNot(contains(qr.secret)));
    expect(jsonDecode(request.body), <String, Object?>{'secret': qr.secret});
    expect(qr.status, 'pending');
  });

  test('a password session runs the passkey step-up first, then '
      'approves', () async {
    final fixture = await signedInWithPassword();
    final qr = server.showQrSignIn();

    final approved = await fixture.auth.approveQrSignIn(
      (await fixture.auth.parseSignInQr(qr.uri)).data,
    );

    expect(approved.isOk, isTrue);
    expect(qr.status, 'approved');
    expect(passkeyStepUpOpenings(), hasLength(1));
    expect(fixture.passkey!.assertionOptionsSeen, hasLength(1));
    expect(approvalCalls(), hasLength(1));
    expect(fixture.auth.state, isA<SignedIn>());
  });

  test("the server's 401 on a session believed recent runs the step-up and "
      'retries exactly once', () async {
    final fixture = await signedInWithPasskey();
    server.expireRecentAuthentications();
    final qr = server.showQrSignIn();

    final approved = await fixture.auth.approveQrSignIn(
      (await fixture.auth.parseSignInQr(qr.uri)).data,
    );

    expect(approved.isOk, isTrue);
    expect(passkeyStepUpOpenings(), hasLength(1));
    expect(approvalCalls(), hasLength(2));
  });

  test('refusals are typed: expired, notFound, notAllowed', () async {
    final fixture = await signedInWithPasskey();
    final expired = server.showQrSignIn(
      expiresAt: DateTime.now().toUtc().subtract(const Duration(seconds: 1)),
    );
    final gated = server.showQrSignIn()..isAllowed = false;
    final wrongSecret = server.showQrSignIn();

    final tooLate = await fixture.auth.approveQrSignIn(
      (await fixture.auth.parseSignInQr(expired.uri)).data,
    );
    final notAllowed = await fixture.auth.approveQrSignIn(
      (await fixture.auth.parseSignInQr(gated.uri)).data,
    );
    final notFound = await fixture.auth.signInQrDetails(
      SignInQr(requestId: wrongSecret.requestId, secret: 'A' * 43),
    );

    expect(
      tooLate.errorOrNull,
      const SignInQrRefused(reason: SignInQrRefusal.expired),
    );
    expect(
      notAllowed.errorOrNull,
      const SignInQrRefused(reason: SignInQrRefusal.notAllowed),
    );
    expect(
      notFound.errorOrNull,
      const SignInQrRefused(reason: SignInQrRefusal.notFound),
    );
    expect(gated.status, 'pending');
  });

  test('deny refuses with no step-up; deciding again is expired', () async {
    final fixture = await signedInWithPassword();
    final qr = server.showQrSignIn();
    final scanned = (await fixture.auth.parseSignInQr(qr.uri)).data;

    final denied = await fixture.auth.denyQrSignIn(scanned);
    final again = await fixture.auth.approveQrSignIn(scanned);

    expect(denied.isOk, isTrue);
    expect(qr.status, 'denied');
    expect(
      again.errorOrNull,
      const SignInQrRefused(reason: SignInQrRefusal.expired),
    );
    expect(approvalCalls(), hasLength(1));
  });
}
