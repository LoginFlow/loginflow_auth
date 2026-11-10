// TEST_CHARTER
// Requirement: the approver side of the sign-in by phone approval
// (`device_push`, `doc/server-contract.md` §21). `pendingPhoneApprovals`
// reads `GET /v1/user/device-push/pending` into typed requests;
// `approvePhoneSignIn` answers one with the chosen number and, because the
// server only takes an approval from a passkey within the last 120 s, runs
// the library's passkey step-up itself — before the call when the session's
// last sign-in is not a recent passkey, or on the RFC 9470 challenge — and
// sends the approval once more; `denyPhoneSignIn` refuses it.
// Oracle: the public `Result`s, and what the fake server recorded: the
// request's final status, every device-push and challenge request it
// received (a step-up opening carries `acr_values=urn:loginflow:acr:phr`
// and `max_age=120`), the passkey ceremonies the authenticator ran.
// Risk edge: the step-up must be the PASSKEY one and the approval must be
// retried exactly once with the new token; a wrong number is a final
// decision (`200 denied wrong_number`), not an error to retry.
// Layer: core, through `LoginFlowAuth` and the real transport against the
// fake server's HTTP dispatch (envelope, `WWW-Authenticate` header, DPoP).
// Counterfactual: with the step-up removed from `approvePhoneSignIn` the
// stale-session cases fail with `StepUpRequired`; with the decision mapping
// reading `denied` as `approved` the wrong-number case fails.

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
    // The company's passkey policy is `passwordless` and the client takes
    // `passkey`: a phr step-up answers the ceremony directly.
    server.loginMethods = <String>[...server.loginMethods, 'passkey'];
  });

  tearDown(() => server.close());

  Future<AuthFixture> signedInWithPasskey({bool enableDpop = false}) async {
    server.requiresDpop = enableDpop;
    final fixture = AuthFixture.create(
      server,
      passkey: FakePasskeyAuthenticator(),
      enableDpop: enableDpop,
    );
    await fixture.auth.initialize();
    final signedIn = await fixture.auth.signInWithPasskey(
      loginHint: 'ana@example.com',
    );
    expect(signedIn.data, isA<SignedIn>());
    return fixture;
  }

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

  List<FakeHttpRequest> approvalCalls() => server.devicePushRequests
      .where((request) => request.uri.path.endsWith('/approve'))
      .toList();

  List<Map<String, String>> passkeyStepUpOpenings() => server.challengeRequests
      .where(
        (form) =>
            form['acr_values'] == LoginFlowAuth.phishingResistantAcr &&
            form['max_age'] == '120',
      )
      .toList();

  test(
    'pending requests are read into typed models, timestamps in UTC',
    () async {
      final fixture = await signedInWithPassword();
      final asked = server.askPhoneApproval(email: 'ana@example.com');

      final pending = await fixture.auth.pendingPhoneApprovals();

      expect(pending.data, <PhoneApprovalRequest>[
        PhoneApprovalRequest(
          requestId: asked.requestId,
          clientId: 'panel-web',
          clientName: 'Payments panel',
          applicationId: FakeLoginFlowServer.applicationId,
          requester: const PhoneApprovalRequester(
            device: 'Chrome on macOS',
            ipAddress: '203.0.113.7',
          ),
          choices: const <int>[17, 42, 85],
          createdAt: asked.createdAt,
          expiresAt: asked.expiresAt,
        ),
      ]);
      expect(pending.data.single.expiresAt.isUtc, isTrue);
      expect(
        PhoneApprovalRequest.fromJson(pending.data.single.toJson()),
        pending.data.single,
      );
    },
  );

  test(
    'a recent passkey sign-in approves with no step-up, DPoP-bound',
    () async {
      final fixture = await signedInWithPasskey(enableDpop: true);
      final asked = server.askPhoneApproval(email: 'ana@example.com');
      final openingsBefore = server.challengeRequests.length;

      final approved = await fixture.auth.approvePhoneSignIn(
        requestId: asked.requestId,
        number: 42,
      );

      expect(approved.data, PhoneApprovalOutcome.approved);
      expect(asked.status, 'approved');
      expect(server.challengeRequests, hasLength(openingsBefore));
      expect(approvalCalls(), hasLength(1));
      expect(
        approvalCalls().single.headers['authorization'],
        startsWith('DPoP '),
      );
      expect(jsonDecode(approvalCalls().single.body), <String, Object?>{
        'number': 42,
      });
    },
  );

  test('a passkey sign-in older than 120 s runs the passkey step-up first, '
      'then approves', () async {
    final fixture = await signedInWithPasskey();
    fixture.clock.advance(const Duration(seconds: 121));
    server.expireRecentAuthentications();
    final asked = server.askPhoneApproval(email: 'ana@example.com');

    final approved = await fixture.auth.approvePhoneSignIn(
      requestId: asked.requestId,
      number: 42,
    );

    expect(approved.data, PhoneApprovalOutcome.approved);
    expect(asked.status, 'approved');
    expect(passkeyStepUpOpenings(), hasLength(1));
    expect(fixture.passkey!.assertionOptionsSeen, hasLength(2));
    expect(approvalCalls(), hasLength(1));
    expect(fixture.auth.state, isA<SignedIn>());
  });

  test('a password sign-in is no passkey: the step-up runs, then it '
      'approves', () async {
    final fixture = await signedInWithPassword();
    final asked = server.askPhoneApproval(email: 'ana@example.com');

    final approved = await fixture.auth.approvePhoneSignIn(
      requestId: asked.requestId,
      number: 42,
    );

    expect(approved.data, PhoneApprovalOutcome.approved);
    expect(passkeyStepUpOpenings(), hasLength(1));
    expect(fixture.passkey!.assertionOptionsSeen, hasLength(1));
  });

  test("the server's 401 challenge on a session the client thought recent "
      'runs the step-up and retries once', () async {
    final fixture = await signedInWithPasskey();
    server.expireRecentAuthentications();
    final asked = server.askPhoneApproval(email: 'ana@example.com');

    final approved = await fixture.auth.approvePhoneSignIn(
      requestId: asked.requestId,
      number: 42,
    );

    expect(approved.data, PhoneApprovalOutcome.approved);
    expect(passkeyStepUpOpenings(), hasLength(1));
    expect(approvalCalls(), hasLength(2));
  });

  test(
    'a wrong number is a final decision: wrongNumber, request denied',
    () async {
      final fixture = await signedInWithPasskey();
      final asked = server.askPhoneApproval(email: 'ana@example.com');

      final answered = await fixture.auth.approvePhoneSignIn(
        requestId: asked.requestId,
        number: 17,
      );

      expect(answered.data, PhoneApprovalOutcome.wrongNumber);
      expect(asked.status, 'denied');
      expect(approvalCalls(), hasLength(1));
    },
  );

  test('a cancelled passkey step-up decides nothing', () async {
    final fixture = await signedInWithPassword();
    fixture.passkey!.shouldCancel = true;
    final asked = server.askPhoneApproval(email: 'ana@example.com');

    final approved = await fixture.auth.approvePhoneSignIn(
      requestId: asked.requestId,
      number: 42,
    );

    expect(
      approved.errorOrNull,
      const PasskeyFailed(reason: PasskeyFailureReason.userCancelled),
    );
    expect(asked.status, 'pending');
    expect(approvalCalls(), isEmpty);
  });

  test('refusals are typed: notFound, expired, notAllowed', () async {
    final fixture = await signedInWithPasskey();
    final expired = server.askPhoneApproval(
      email: 'ana@example.com',
      requestId: 'expired-request',
      expiresAt: DateTime.now().toUtc().subtract(const Duration(seconds: 1)),
    );
    final gated = server.askPhoneApproval(
      email: 'ana@example.com',
      requestId: 'gated-request',
      isAllowed: false,
    );

    final notFound = await fixture.auth.approvePhoneSignIn(
      requestId: 'someone-elses-request',
      number: 42,
    );
    final tooLate = await fixture.auth.approvePhoneSignIn(
      requestId: expired.requestId,
      number: 42,
    );
    final notAllowed = await fixture.auth.approvePhoneSignIn(
      requestId: gated.requestId,
      number: 42,
    );

    expect(
      notFound.errorOrNull,
      const PhoneApprovalRefused(reason: PhoneApprovalRefusal.notFound),
    );
    expect(
      tooLate.errorOrNull,
      const PhoneApprovalRefused(reason: PhoneApprovalRefusal.expired),
    );
    expect(
      notAllowed.errorOrNull,
      const PhoneApprovalRefused(reason: PhoneApprovalRefusal.notAllowed),
    );
    expect(gated.status, 'pending');
  });

  test('deny refuses the request with no step-up; a second decision is '
      'expired', () async {
    final fixture = await signedInWithPassword();
    final asked = server.askPhoneApproval(email: 'ana@example.com');

    final denied = await fixture.auth.denyPhoneSignIn(asked.requestId);
    final again = await fixture.auth.denyPhoneSignIn(asked.requestId);

    expect(denied.isOk, isTrue);
    expect(asked.status, 'denied');
    expect(passkeyStepUpOpenings(), isEmpty);
    expect(
      again.errorOrNull,
      const PhoneApprovalRefused(reason: PhoneApprovalRefusal.expired),
    );
  });

  test('signed out: NotSignedIn, nothing sent', () async {
    final fixture = AuthFixture.create(server);
    await fixture.auth.initialize();

    final pending = await fixture.auth.pendingPhoneApprovals();
    final approved = await fixture.auth.approvePhoneSignIn(
      requestId: 'any',
      number: 42,
    );

    expect(pending.errorOrNull, const NotSignedIn());
    expect(approved.errorOrNull, const NotSignedIn());
    expect(server.devicePushRequests, isEmpty);
  });
}
