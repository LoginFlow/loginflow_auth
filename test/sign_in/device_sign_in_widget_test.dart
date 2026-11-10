// TEST_CHARTER
// Requirement: the built-in sign-in UI offers the two sign-ins on another
// device only when the client allows them (configured methods ∩ the
// server's login options): "Approve on my phone" asks for the email, then
// shows the number large with its countdown; "Sign in with a QR code"
// renders the QR with its countdown. Approved: signed in. Refused or
// expired: the reason, and an action to try again with a new one.
// Oracle: what the person sees (method buttons, the number, the QR
// widget, "Expires in m:ss" read from the core's clock, the feedback text,
// the try-again action) and the session handed to `onSignedIn`.
// Risk edge: a method the client does not allow must not be offered; the
// countdown must follow the core's clock; a refused QR must not leave the
// person stuck on a dead code.
// Layer: widget, the public `LoginFlowSignIn` over a real `LoginFlowAuth`
// against the in-memory fake server; only time is driven (a test clock
// and a manual poll scheduler). The phone's decision is set on the fake
// server (its approver routes are covered in the core tests).
// Counterfactual: without the `device_push`/`device_qr` cases the methods
// never appear; without `StepError.denied` → feedback the refusal shows no
// message.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loginflow_auth/loginflow_auth.dart';
import 'package:loginflow_auth/src/sign_in/ui/sign_in_keys.dart';

import '../support/fake_login_flow_server.dart';
import '../support/manual_scheduler.dart';
import '../support/sign_in_harness.dart';
import '../support/test_clock.dart';
import '../support/test_signing_keys.dart';

void main() {
  late TestSigningKeys keys;
  late FakeLoginFlowServer server;
  late ManualScheduler scheduler;
  late TestClock clock;

  setUpAll(() => keys = TestSigningKeys.generate());

  setUp(() {
    server = FakeLoginFlowServer.inMemory(keys)
      ..loginMethods = <String>['password', 'device_push', 'device_qr'];
    scheduler = ManualScheduler();
    clock = TestClock();
  });

  const configuration = SignInConfiguration(
    methods: <AuthMethod>[
      PasswordMethod(),
      PhoneApprovalMethod(),
      QrSignInMethod(),
    ],
    isPasskeySignInOffered: false,
  );

  Finder method(String wireName) => find.byKey(
    ValueKey<String>('${SignInKeys.methodButtonPrefix}.$wireName'),
  );

  SignInHarness install() => SignInHarness.install(
    server,
    configuration,
    clock: clock,
    scheduler: scheduler,
  );

  /// Lets the core's next poll run, and the UI settle on its answer.
  Future<void> poll(WidgetTester tester) async {
    expect(scheduler.runNext(), isTrue, reason: 'no poll was scheduled');
    await tester.pumpAndSettle();
  }

  testWidgets('only the methods the client allows are offered', (tester) async {
    server.loginMethods = <String>['password', 'device_push'];
    await install().pump(tester);

    expect(method('device_push'), findsOneWidget);
    expect(find.text('Approve on my phone'), findsOneWidget);
    expect(method('device_qr'), findsNothing);
  });

  testWidgets('phone approval: email, then the number large with its '
      'countdown; approved on the phone, signed in', (tester) async {
    final harness = install();
    await harness.pump(tester);

    await tester.tap(method('device_push'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(SignInKeys.emailField),
      'ana@example.com',
    );
    await tester.tap(find.text('Send to my phone'));
    await tester.pumpAndSettle();

    expect(
      tester.widget<Text>(find.byKey(SignInKeys.phoneApprovalNumber)).data,
      '42',
    );
    expect(
      find.text('Open the app on your phone and choose this number.'),
      findsOneWidget,
    );
    expect(find.text('Expires in 2:00'), findsOneWidget);

    clock.advance(const Duration(seconds: 18));
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Expires in 1:42'), findsOneWidget);

    server.phoneApprovals.values.single
      ..status = 'approved'
      ..approver = server.users['ana@example.com'];
    await poll(tester);

    expect(harness.signedIn.single.identity.email, 'ana@example.com');
  });

  testWidgets('QR: rendered with its countdown; refused on the phone, the '
      'reason and a new code', (tester) async {
    await install().pump(tester);

    await tester.tap(method('device_qr'));
    await tester.pumpAndSettle();

    expect(find.byKey(SignInKeys.qrSignInCode), findsOneWidget);
    expect(find.bySemanticsLabel('QR code to sign in'), findsOneWidget);
    expect(find.text('Expires in 2:00'), findsOneWidget);

    server.qrSignIns.values.single.status = 'denied';
    await poll(tester);

    expect(find.byKey(SignInKeys.qrSignInCode), findsNothing);
    expect(find.text('The sign-in was refused on the phone.'), findsOneWidget);

    await tester.tap(find.text('Show a new code'));
    await tester.pumpAndSettle();

    expect(find.byKey(SignInKeys.qrSignInCode), findsOneWidget);
    expect(server.qrSignIns, hasLength(2));

    clock.advance(const Duration(seconds: 120));
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Expires in 0:00'), findsOneWidget);
  });
}
