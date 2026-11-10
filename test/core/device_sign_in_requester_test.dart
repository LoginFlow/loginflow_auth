// TEST_CHARTER
// Requirement: the requester side of the two sign-ins on another device
// (`doc/server-contract.md` §21). `requestPhoneApproval(email)` asks for a
// `device_push` and `requestQrSignIn()` for a `device_qr`; both resolve once
// the request exists, with the number or the QR in `ChallengeRequired`,
// then the library polls by itself (`method=*_poll`) at the server's
// interval, 5 s more after every `slow_down`, until the request is
// approved (signed in as the approver), denied or expired (the same step
// with `StepError.denied` / `StepError.expired` and nothing on screen).
// Cancelling stops the polling.
// Oracle: the public states and `Result`s, the forms the fake server
// received, the delays the library asked the scheduler for, and the
// signed-in identity — approved by a second, real `LoginFlowAuth` (the
// phone) through the approver routes.
// Risk edge: polling: interval and slow_down growth, terminal answers that
// must stop it, an approval that must end in a stored session of the
// APPROVER, a cancel that must leave no poll behind.
// Layer: core, two `LoginFlowAuth` instances against the fake server over
// real HTTP; only time is driven (a manual scheduler).
// Counterfactual: without the slow_down growth the slow_down case asks for
// 2 s; without the access_denied/expired_token mapping the attempt is
// abandoned (SignedOut) instead of keeping the step with its reason;
// without `_stopPolling` in `cancelChallenge` a poll stays scheduled.

import 'package:flutter_test/flutter_test.dart';
import 'package:loginflow_auth/loginflow_auth_core.dart';

import '../support/auth_fixture.dart';
import '../support/fake_login_flow_server.dart';
import '../support/fake_passkey_authenticator.dart';
import '../support/manual_scheduler.dart';
import '../support/test_signing_keys.dart';

void main() {
  late TestSigningKeys keys;
  late FakeLoginFlowServer server;
  late ManualScheduler scheduler;
  late AuthFixture page;

  setUpAll(() => keys = TestSigningKeys.generate());

  setUp(() async {
    server = await FakeLoginFlowServer.start(keys);
    server.loginMethods = <String>[
      ...server.loginMethods,
      'passkey',
      'device_push',
      'device_qr',
    ];
    scheduler = ManualScheduler();
    page = AuthFixture.create(server, scheduler: scheduler);
    await page.auth.initialize();
  });

  tearDown(() => server.close());

  /// The phone: an app of the same company, signed in with a passkey.
  Future<AuthFixture> phoneSignedIn() async {
    final phone = AuthFixture.create(
      server,
      passkey: FakePasskeyAuthenticator(),
    );
    await phone.auth.initialize();
    final signedIn = await phone.auth.signInWithPasskey(
      loginHint: 'ana@example.com',
    );
    expect(signedIn.data, isA<SignedIn>());
    return phone;
  }

  /// Fires the scheduled poll and waits until the library either
  /// schedules the next one or emits a state.
  Future<void> poll() async {
    final next = Future.any<Object?>(<Future<Object?>>[
      scheduler.nextScheduled,
      page.auth.states.first,
    ]);
    expect(scheduler.runNext(), isTrue, reason: 'no poll was scheduled');
    await next;
  }

  List<Map<String, String>> polls(String method) => server.challengeRequests
      .where((form) => form['method'] == method)
      .toList();

  group('phone approval (device_push)', () {
    test('shows the number, polls at the interval, and signs in as the '
        'approver once the phone approves', () async {
      final phone = await phoneSignedIn();

      final requested = await page.auth.requestPhoneApproval('ana@example.com');

      final prompt = (requested.data as ChallengeRequired).prompt;
      expect(prompt.step, ChallengeStep.devicePush);
      expect(
        prompt.phoneApproval,
        PhoneApproval(
          number: 42,
          expiresAt: page.clock.now().add(const Duration(seconds: 120)),
        ),
      );
      expect(server.challengeRequests.last['login_hint'], 'ana@example.com');
      expect(server.challengeRequests.last['method'], 'device_push');
      expect(scheduler.delays, <Duration>[const Duration(seconds: 2)]);
      expect(page.auth.deviceSignInWait, const Duration(seconds: 120));

      await poll();
      expect(page.auth.state, requested.data, reason: 'pending emits nothing');
      expect(polls('device_push_poll'), hasLength(1));

      final pending = await phone.auth.pendingPhoneApprovals();
      final approved = await phone.auth.approvePhoneSignIn(
        requestId: pending.data.single.requestId,
        number: 42,
      );
      expect(approved.data, PhoneApprovalOutcome.approved);

      await poll();

      final state = page.auth.state;
      expect(state, isA<SignedIn>());
      expect((state as SignedIn).session.identity.email, 'ana@example.com');
      expect((await page.storedSession())?.idToken, isNotEmpty);
      expect(scheduler.pendingCount, 0);
    });

    test('denied on the phone: the step stays, without the number, with '
        'StepError.denied, and polling stops', () async {
      final phone = await phoneSignedIn();
      await page.auth.requestPhoneApproval('ana@example.com');
      final pending = await phone.auth.pendingPhoneApprovals();
      await phone.auth.denyPhoneSignIn(pending.data.single.requestId);

      await poll();

      final state = page.auth.state as ChallengeRequired;
      expect(state.prompt.step, ChallengeStep.devicePush);
      expect(state.prompt.stepError, StepError.denied);
      expect(state.prompt.phoneApproval, isNull);
      expect(scheduler.pendingCount, 0);
      expect(page.auth.deviceSignInWait, Duration.zero);
    });

    test('nobody answers: StepError.expired, polling stops; asking again '
        'shows a new number', () async {
      await page.auth.requestPhoneApproval('ana@example.com');
      server.expireDeviceRequests();

      await poll();

      final ended = page.auth.state as ChallengeRequired;
      expect(ended.prompt.stepError, StepError.expired);
      expect(ended.prompt.phoneApproval, isNull);
      expect(scheduler.pendingCount, 0);

      server.nextPhoneApprovalNumber = 17;
      final again = await page.auth.requestPhoneApproval('ana@example.com');

      final prompt = (again.data as ChallengeRequired).prompt;
      expect(prompt.phoneApproval?.number, 17);
      expect(prompt.stepError, isNull);
      expect(scheduler.pendingCount, 1);
    });

    test('slow_down adds 5 s to the interval, for good', () async {
      await page.auth.requestPhoneApproval('ana@example.com');
      server.slowDownNextDevicePoll = true;

      await poll();
      await poll();

      expect(scheduler.delays, <Duration>[
        const Duration(seconds: 2),
        const Duration(seconds: 7),
        const Duration(seconds: 7),
      ]);
      expect(page.auth.state, isA<ChallengeRequired>());
    });

    test('a client without device_push: unsupported_client, nothing is '
        'polled', () async {
      server.loginMethods = <String>['password', 'email_otp'];

      final requested = await page.auth.requestPhoneApproval('ana@example.com');

      expect(
        requested.errorOrNull,
        isA<OAuthProtocolError>().having(
          (error) => error.code,
          'code',
          'unsupported_client',
        ),
      );
      expect(scheduler.pendingCount, 0);
    });
  });

  group('QR (device_qr)', () {
    test('shows the QR, and signs in as whoever approves it on the phone '
        '(after its passkey step-up)', () async {
      final phone = AuthFixture.create(
        server,
        passkey: FakePasskeyAuthenticator(),
      );
      await phone.auth.initialize();
      await phone.auth.signInWithPassword(
        loginHint: 'ana@example.com',
        password: 'correct-horse',
      );

      final requested = await page.auth.requestQrSignIn();

      final prompt = (requested.data as ChallengeRequired).prompt;
      expect(prompt.step, ChallengeStep.deviceQr);
      final qrSignIn = prompt.qrSignIn!;
      expect(qrSignIn.qrUri.host, FakeLoginFlowServer.passkeyRpId);
      expect(server.challengeRequests.last['method'], 'device_qr');
      expect(server.challengeRequests.last.containsKey('login_hint'), isFalse);

      await poll();
      expect(polls('device_qr_poll'), hasLength(1));

      final scanned = phone.auth.parseSignInQr(qrSignIn.qrUri.toString());
      final approved = await phone.auth.approveQrSignIn(scanned.data);
      expect(approved.isOk, isTrue);

      await poll();

      final state = page.auth.state;
      expect(state, isA<SignedIn>());
      expect((state as SignedIn).session.identity.email, 'ana@example.com');
      expect(scheduler.pendingCount, 0);
    });

    test('cancelling stops the polling: no poll is left to run', () async {
      await page.auth.requestQrSignIn();
      expect(scheduler.pendingCount, 1);

      await page.auth.cancelChallenge();

      expect(scheduler.pendingCount, 0);
      expect(scheduler.runNext(), isFalse);
      expect(polls('device_qr_poll'), isEmpty);
      expect(page.auth.state, isA<SignedOut>());
    });
  });
}
