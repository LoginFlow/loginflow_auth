import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:loginflow_auth/loginflow_auth_core.dart';

import '../support/auth_fixture.dart';
import '../support/fake_login_flow_server.dart';
import '../support/fake_passkey_authenticator.dart';
import '../support/test_signing_keys.dart';

const String _luz = 'luz@example.com';
const String _luzPassword = 'Luz-Password-1';
const String _ana = 'ana@example.com';
const String _tomas = 'tomas@example.com';
const String _newPassword = 'N3w-Passw0rd!';
const String _wrongCode = '000000';

/// The in-app password reset (`startPasswordReset` → `submitResetCode` →
/// `setNewPassword`) against the fake LoginFlow: the email-code sign-in of
/// the authorization challenge, `POST /v1/user/change-password`, and the
/// step-up the server asks for an account with a second factor. The app
/// never sees `SignedIn` before the new password is set, nothing is stored
/// before that, and no browser ever opens.
void main() {
  late TestSigningKeys keys;
  late FakeLoginFlowServer server;

  setUpAll(() => keys = TestSigningKeys.generate());

  setUp(() async {
    server = await FakeLoginFlowServer.start(keys);
    server.requiresDpop = true;
    // An account with no second factor: no TOTP, no passkey.
    server.users[_luz] = const FakeUser(
      subject: 'cu_luz',
      email: _luz,
      password: _luzPassword,
      name: 'Luz Mar',
    );
  });

  tearDown(() => server.close());

  /// A started app, with every state it publishes from now on.
  Future<(AuthFixture, List<AuthState>)> started({
    FakePasskeyAuthenticator? passkey,
  }) async {
    if (passkey != null) {
      // The client offers passkeys, so the step-up's password step lists
      // `webauthn_identify` among its `methods`.
      server.loginMethods = <String>[...server.loginMethods, 'passkey'];
    }
    final fixture = AuthFixture.create(
      server,
      enableDpop: true,
      passkey: passkey,
    );
    await fixture.auth.initialize();
    final states = <AuthState>[];
    fixture.auth.states.listen(states.add);
    return (fixture, states);
  }

  /// [fixture] with the reset of [email] past its code.
  Future<void> codeAccepted(AuthFixture fixture, String email) async {
    await fixture.auth.startPasswordReset(email);
    await fixture.auth.submitResetCode(FakeLoginFlowServer.emailOtpCode);
  }

  /// The answer to [password] for [email], on a fresh app.
  Future<AuthState?> signInAnswer(String email, String password) async {
    final fixture = AuthFixture.create(server, enableDpop: true);
    await fixture.auth.initialize();
    final result = await fixture.auth.signInWithPassword(
      loginHint: email,
      password: password,
    );
    return result.when(ok: (state) => state, err: (_) => null);
  }

  /// Whether [password] signs [email] in, on a fresh app.
  Future<bool> signsIn(String email, String password) async =>
      await signInAnswer(email, password) is SignedIn;

  /// Whether [password] is accepted for [email]: signed in, or on to the
  /// second factor with no refusal.
  Future<bool> passwordAccepted(String email, String password) async =>
      switch (await signInAnswer(email, password)) {
        SignedIn() => true,
        ChallengeRequired(:final prompt) =>
          prompt.step == ChallengeStep.totp && prompt.stepError == null,
        _ => false,
      };

  // TEST_CHARTER
  // Requirement: a person who forgot the password gets a code by email,
  // types it, sets a new password, and only then is signed in — all in the
  // app.
  // Oracle: the published states in order, the session store (empty until
  // the password is set), the browser never opened, no `intent` on any
  // challenge request, and the new password signing in on another app.
  // Risk edge: the emailed code surfacing a normal `SignedIn` (the app
  // would open its home screen with the old password still in place), or
  // the held session persisted before the password changes.
  // Layer: integration against the fake LoginFlow (real HTTP, real DPoP).
  // Counterfactual: emitting `SignedIn` when the code is accepted, or
  // writing the session then, breaks the state order or the empty store.
  test('code, then new password, then SignedIn — never earlier, no '
      'browser, nothing stored before the password changes', () async {
    final (fixture, states) = await started();

    final opened = await fixture.auth.startPasswordReset(_luz);
    expect(opened.data, const AwaitingResetCode(email: _luz));
    expect(server.sentEmailOtps, <String>[_luz]);

    final verified = await fixture.auth.submitResetCode(
      FakeLoginFlowServer.emailOtpCode,
    );
    expect(verified.data, const AwaitingNewPassword(email: _luz));
    expect(await fixture.storedSession(), isNull);
    await pumpEventQueue();
    expect(states.whereType<SignedIn>(), isEmpty);

    final done = await fixture.auth.setNewPassword(_newPassword);

    await pumpEventQueue();
    final signedIn = done.data as SignedIn;
    expect(signedIn.session.identity.subject, 'cu_luz');
    expect(fixture.auth.state, signedIn);
    expect(states, <AuthState>[
      const AwaitingResetCode(email: _luz),
      const AwaitingNewPassword(email: _luz),
      signedIn,
    ]);
    expect(await fixture.storedSession(), isNotNull);
    expect(server.changePasswordRequests, hasLength(1));
    expect(fixture.browser.openedUrls, isEmpty);
    expect(
      server.challengeRequests.where((form) => form.containsKey('intent')),
      isEmpty,
    );
    expect(await signsIn(_luz, _newPassword), isTrue);
    expect(await signsIn(_luz, _luzPassword), isFalse);
  });

  // TEST_CHARTER
  // Requirement: a wrong code is a typed refusal; the reset stays on the
  // code and the right code still works.
  // Oracle: the public `Result`, the state after the refusal.
  // Risk edge: the server's `step_error` on the `email_otp` step read as a
  // generic `ChallengeRequired`, or the reset dropped.
  // Layer: integration against the fake LoginFlow.
  // Counterfactual: answering `Ok` for a refused code leaves no
  // `InvalidResetCode`.
  test('a wrong code -> InvalidResetCode, still on the code', () async {
    final (fixture, _) = await started();
    await fixture.auth.startPasswordReset(_luz);

    final wrong = await fixture.auth.submitResetCode(_wrongCode);

    expect(wrong.errorOrNull, const InvalidResetCode());
    expect(fixture.auth.state, const AwaitingResetCode(email: _luz));
    final right = await fixture.auth.submitResetCode(
      FakeLoginFlowServer.emailOtpCode,
    );
    expect(right.data, const AwaitingNewPassword(email: _luz));
  });

  // TEST_CHARTER
  // Requirement: an expired (or burned) code is its own typed refusal, so
  // the app offers a new one.
  // Oracle: the public `Result` and state.
  // Risk edge: `code_expired` read as a wrong code.
  // Layer: integration against the fake LoginFlow.
  // Counterfactual: mapping every `step_error` to `InvalidResetCode`.
  test('an expired code -> ResetCodeExpired, still on the code', () async {
    final (fixture, _) = await started();
    await fixture.auth.startPasswordReset(_luz);
    server.isEmailOtpExpired = true;

    final expired = await fixture.auth.submitResetCode(
      FakeLoginFlowServer.emailOtpCode,
    );

    expect(expired.errorOrNull, const ResetCodeExpired());
    expect(fixture.auth.state, const AwaitingResetCode(email: _luz));
  });

  // TEST_CHARTER
  // Requirement: "resend" asks the server for another code on the same
  // reset; the server answers every request as sent (it emails nothing
  // inside its interval), so the reset simply stays on the code.
  // Oracle: the public `Result`, the `resend` request the server received,
  // and the code still accepted.
  // Risk edge: a resend that restarts the attempt (a new `auth_session`,
  // the first code void) or reports an error for a too-early request.
  // Layer: integration against the fake LoginFlow.
  // Counterfactual: starting a new reset instead of `resend` sends no
  // `resend` field.
  test('resend asks for another code on the same reset', () async {
    final (fixture, _) = await started();
    await fixture.auth.startPasswordReset(_luz);

    final resent = await fixture.auth.resendResetCode();

    expect(resent.data, const AwaitingResetCode(email: _luz));
    expect(server.challengeRequests.last['resend'], 'email_otp');
    expect(server.sentEmailOtps, <String>[_luz, _luz]);
    final verified = await fixture.auth.submitResetCode(
      FakeLoginFlowServer.emailOtpCode,
    );
    expect(verified.data, const AwaitingNewPassword(email: _luz));
  });

  // TEST_CHARTER
  // Requirement: an address with no account looks exactly like one with an
  // account (anti-enumeration); no code ever works for it.
  // Oracle: the public `Result` of the start and of a code.
  // Risk edge: an error or a different state for an unknown address.
  // Layer: integration against the fake LoginFlow.
  // Counterfactual: refusing the start for an unknown address.
  test('an unknown address starts the same; its code is refused', () async {
    final (fixture, _) = await started();

    final opened = await fixture.auth.startPasswordReset('nobody@x.com');
    final code = await fixture.auth.submitResetCode(
      FakeLoginFlowServer.emailOtpCode,
    );

    expect(opened.data, const AwaitingResetCode(email: 'nobody@x.com'));
    expect(code.errorOrNull, const InvalidResetCode());
  });

  // TEST_CHARTER
  // Requirement: a rate-limited request is a typed `RateLimited` with the
  // server's wait; the reset stays where it was.
  // Oracle: the public `Result` and state.
  // Risk edge: a 429 that ends the reset or leaves a broken state.
  // Layer: integration against the fake LoginFlow.
  // Counterfactual: abandoning the attempt on any error.
  test('a rate-limited code -> RateLimited, still on the code', () async {
    final (fixture, _) = await started();
    await fixture.auth.startPasswordReset(_luz);
    server.rateLimitNextChallenge = const Duration(seconds: 60);

    final limited = await fixture.auth.submitResetCode(
      FakeLoginFlowServer.emailOtpCode,
    );

    expect(
      limited.errorOrNull,
      const RateLimited(retryAfter: Duration(seconds: 60)),
    );
    expect(fixture.auth.state, const AwaitingResetCode(email: _luz));
  });

  // TEST_CHARTER
  // Requirement: an account with TOTP answers its second factor inside the
  // reset (the code alone does not sign it in), then sets the password.
  // Oracle: the published states and the final `SignedIn`.
  // Risk edge: the TOTP prompt surfaced as a sign-in challenge (`signIn`
  // purpose) the app would treat as a normal login, or `SignedIn` before
  // the password.
  // Layer: integration against the fake LoginFlow.
  // Counterfactual: keeping the attempt's `signIn` purpose.
  test('an account with TOTP: code, TOTP, new password, SignedIn', () async {
    final (fixture, states) = await started();
    await fixture.auth.startPasswordReset(_tomas);

    final second = await fixture.auth.submitResetCode(
      FakeLoginFlowServer.emailOtpCode,
    );
    final prompt = second.data as ChallengeRequired;
    expect(prompt.purpose, ChallengePurpose.passwordReset);
    expect(prompt.prompt.step, ChallengeStep.totp);

    final verified = await fixture.auth.submitTotp(
      FakeLoginFlowServer.totpCode,
    );
    expect(verified.data, const AwaitingNewPassword(email: _tomas));
    final done = await fixture.auth.setNewPassword(_newPassword);

    await pumpEventQueue();
    expect((done.data as SignedIn).session.identity.subject, 'cu_tomas');
    expect(states.whereType<SignedIn>(), hasLength(1));
    expect(states.last, isA<SignedIn>());
    expect(await passwordAccepted(_tomas, _newPassword), isTrue);
    expect(server.changePasswordRequests, hasLength(1));
  });

  // TEST_CHARTER
  // Requirement: an account with a passkey and no TOTP: the code signs it
  // in weakly, the password change answers a strong step-up, the person
  // confirms with the passkey, and the password is set without typing it
  // again.
  // Oracle: the step-up prompt's purpose, the two change-password requests
  // (401, then 200), the final `SignedIn` and the new password signing in.
  // Risk edge: the step-up's `SignedIn` surfacing before the password is
  // set, the retry forgotten, or a browser opened.
  // Layer: integration against the fake LoginFlow.
  // Counterfactual: returning `StepUpRequired` to the app instead of
  // running the step-up leaves the password unchanged.
  test('an account with a passkey: step-up, then the password is set and '
      'the person signed in', () async {
    final (fixture, states) = await started(
      passkey: FakePasskeyAuthenticator(),
    );
    await codeAccepted(fixture, _ana);

    final stepUp = await fixture.auth.setNewPassword(_newPassword);
    final prompt = stepUp.data as ChallengeRequired;
    expect(prompt.purpose, ChallengePurpose.passwordReset);
    expect(
      prompt.prompt.alternatives,
      contains(ChallengeStep.webauthnIdentify),
    );
    await pumpEventQueue();
    expect(states.whereType<SignedIn>(), isEmpty);

    final done = await fixture.auth.selectMethod(
      ChallengeStep.webauthnIdentify,
    );

    await pumpEventQueue();
    expect((done.data as SignedIn).session.identity.subject, 'cu_ana');
    expect(states.whereType<SignedIn>(), hasLength(1));
    expect(server.changePasswordRequests, hasLength(2));
    expect(await fixture.storedSession(), isNotNull);
    expect(fixture.browser.openedUrls, isEmpty);
    expect(await signsIn(_ana, _newPassword), isTrue);
  });

  // TEST_CHARTER
  // Requirement: a weak, breached or unchanged password is
  // `PasswordRejected(reason)`; the reset stays on the new password, the
  // session still held and unstored, and another password works.
  // Oracle: the public `Result`, the state, the store.
  // Risk edge: the refusal ending the reset (the person would need a new
  // code) or surfacing `SignedIn`.
  // Layer: integration against the fake LoginFlow.
  // Counterfactual: abandoning the reset on any change-password error.
  test('a refused password keeps AwaitingNewPassword', () async {
    final (fixture, states) = await started();
    await codeAccepted(fixture, _luz);

    final weak = await fixture.auth.setNewPassword('short');
    final same = await fixture.auth.setNewPassword(_luzPassword);

    expect(
      weak.errorOrNull,
      const PasswordRejected(reason: FakeLoginFlowServer.weakPasswordDetails),
    );
    expect(
      same.errorOrNull,
      const PasswordRejected(reason: FakeLoginFlowServer.samePasswordDetails),
    );
    expect(fixture.auth.state, const AwaitingNewPassword(email: _luz));
    expect(await fixture.storedSession(), isNull);
    await pumpEventQueue();
    expect(states.whereType<SignedIn>(), isEmpty);
    final done = await fixture.auth.setNewPassword(_newPassword);
    expect(done.data, isA<SignedIn>());
  });

  // TEST_CHARTER
  // Requirement: a password refused only after the step-up (the server
  // checks the sign-in before the strength) goes back to the new password,
  // still held.
  // Oracle: the `Result` of the call that finished the step-up, the state.
  // Risk edge: the step-up's session surfacing as `SignedIn` when the
  // retried change fails.
  // Layer: integration against the fake LoginFlow.
  // Counterfactual: emitting the step-up's `SignedIn` before the retry.
  test(
    'a password refused after the step-up keeps AwaitingNewPassword',
    () async {
      final (fixture, states) = await started(
        passkey: FakePasskeyAuthenticator(),
      );
      await codeAccepted(fixture, _ana);
      await fixture.auth.setNewPassword('short');

      final retried = await fixture.auth.selectMethod(
        ChallengeStep.webauthnIdentify,
      );

      expect(
        retried.errorOrNull,
        const PasswordRejected(reason: FakeLoginFlowServer.weakPasswordDetails),
      );
      expect(fixture.auth.state, const AwaitingNewPassword(email: _ana));
      await pumpEventQueue();
      expect(states.whereType<SignedIn>(), isEmpty);
      expect(await fixture.storedSession(), isNull);
      final done = await fixture.auth.setNewPassword(_newPassword);
      expect(done.data, isA<SignedIn>());
    },
  );

  // TEST_CHARTER
  // Requirement: the held session keeps working past its access token's
  // lifetime, and its refresh is neither stored nor announced.
  // Oracle: the store after a refused password that needed a refresh, and
  // the states.
  // Risk edge: the refresh path writing the session (a restart would then
  // sign in without the new password) or emitting `SignedIn`.
  // Layer: integration against the fake LoginFlow.
  // Counterfactual: persisting every refresh, as for a signed-in session.
  test('a refresh while the password is awaited is not stored', () async {
    final (fixture, states) = await started();
    await codeAccepted(fixture, _luz);
    fixture.clock.advance(const Duration(minutes: 15));
    final refreshesBefore = server.tokenRequests.length;

    final weak = await fixture.auth.setNewPassword('short');

    expect(weak.errorOrNull, isA<PasswordRejected>());
    expect(server.tokenRequests.length, refreshesBefore + 1);
    expect(await fixture.storedSession(), isNull);
    await pumpEventQueue();
    expect(states.whereType<SignedIn>(), isEmpty);
  });

  // TEST_CHARTER
  // Requirement: the held session is not a signed-in one for the app: no
  // API token comes out of it before the new password is set.
  // Oracle: the public `Result` of `accessTokenFor`, no token request.
  // Risk edge: the app calling its API with the code's session.
  // Layer: integration against the fake LoginFlow.
  // Counterfactual: `accessTokenFor` reading the held session.
  test('no API token while the password is awaited', () async {
    final (fixture, _) = await started();
    await codeAccepted(fixture, _luz);
    final tokenRequestsBefore = server.tokenRequests.length;

    final token = await fixture.auth.accessTokenFor(
      FakeLoginFlowServer.routesApi,
    );

    expect(token.errorOrNull, const NotSignedIn());
    expect(server.tokenRequests, hasLength(tokenRequestsBefore));
  });

  // TEST_CHARTER
  // Requirement: with Native SSO, the held session reaches the shared
  // device store only once the reset completes, and the app's resume check
  // (`verifyDeviceSession`) does not end the reset meanwhile.
  // Oracle: the shared SSO store before and after, and the state after the
  // resume check.
  // Risk edge: siblings offered "Continue as …" for a session whose
  // password is not set yet, or the reset killed because that entry is not
  // there yet.
  // Layer: integration against the fake LoginFlow.
  // Counterfactual: writing the device secret when the code is accepted, or
  // `verifyDeviceSession` treating the missing entry as a device logout.
  test('Native SSO: shared only after the password is set; a resume check '
      'keeps the reset', () async {
    final shared = InMemorySsoStore();
    final fixture = AuthFixture.create(
      server,
      enableDpop: true,
      ssoStore: shared,
    );
    await fixture.auth.initialize();
    await codeAccepted(fixture, _luz);
    final issuer = server.issuer.toString();

    expect((await shared.read(issuer)).data, isNull);
    await fixture.auth.verifyDeviceSession();
    expect(fixture.auth.state, const AwaitingNewPassword(email: _luz));

    final done = await fixture.auth.setNewPassword(_newPassword);

    expect(done.data, isA<SignedIn>());
    expect((await shared.read(issuer)).data, isNotNull);
  });

  group('cancel', () {
    // TEST_CHARTER
    // Requirement: "back" on the code ends the reset: SignedOut, nothing
    // left, the code no longer accepted.
    // Oracle: the public `Result`, state, store, and a later code refused.
    // Risk edge: a reset left half-open that a later call resumes.
    // Layer: integration against the fake LoginFlow.
    // Counterfactual: only clearing the state, not the attempt.
    test('on the code -> SignedOut, the reset gone', () async {
      final (fixture, _) = await started();
      await fixture.auth.startPasswordReset(_luz);
      expect(fixture.auth.state, const AwaitingResetCode(email: _luz));

      final cancelled = await fixture.auth.cancelPasswordReset();

      expect(cancelled.data, isA<SignedOut>());
      expect(fixture.auth.state, isA<SignedOut>());
      final late = await fixture.auth.submitResetCode(
        FakeLoginFlowServer.emailOtpCode,
      );
      expect(late.errorOrNull, const NoChallengeInProgress());
      expect(await fixture.storedSession(), isNull);
    });

    // TEST_CHARTER
    // Requirement: "back" on the second factor of the code ends the reset.
    // Oracle: the state and the store.
    // Risk edge: the challenge cancelled but the reset kept.
    // Layer: integration against the fake LoginFlow.
    // Counterfactual: cancelling only the challenge.
    test('on the TOTP of the code -> SignedOut', () async {
      final (fixture, _) = await started();
      await codeAccepted(fixture, _tomas);
      expect(fixture.auth.state, isA<ChallengeRequired>());

      final cancelled = await fixture.auth.cancelPasswordReset();

      expect(cancelled.data, isA<SignedOut>());
      expect(await fixture.storedSession(), isNull);
      expect(server.tokenRequests, isEmpty);
    });

    // TEST_CHARTER
    // Requirement: "back" on the new password signs the held session out
    // (app scope): SignedOut, its refresh token revoked on the server,
    // nothing stored.
    // Oracle: the state, the revocation the server received, a refresh
    // with that token refused, the store.
    // Risk edge: the held session left alive on the server, or stored.
    // Layer: integration against the fake LoginFlow.
    // Counterfactual: dropping the session locally without revoking it.
    test(
      'on the new password -> SignedOut and the held session revoked',
      () async {
        final (fixture, _) = await started();
        await codeAccepted(fixture, _luz);
        final heldToken = server.lastIssuedRefreshToken;

        final cancelled = await fixture.auth.cancelPasswordReset();

        expect(cancelled.data, isA<SignedOut>());
        expect(
          server.revocationRequests.map((form) => form['token']),
          contains(heldToken),
        );
        expect(await fixture.storedSession(), isNull);
        final late = await fixture.auth.setNewPassword(_newPassword);
        expect(late.errorOrNull, const NoChallengeInProgress());
        expect(server.changePasswordRequests, isEmpty);
      },
    );

    // TEST_CHARTER
    // Requirement: "back" during the step-up of the new password also ends
    // the reset and its held session.
    // Oracle: the state, the revocation.
    // Risk edge: cancelling the step-up only, leaving the session held.
    // Layer: integration against the fake LoginFlow.
    // Counterfactual: routing to `cancelChallenge`.
    test('on the step-up -> SignedOut and the held session revoked', () async {
      final (fixture, _) = await started(passkey: FakePasskeyAuthenticator());
      await codeAccepted(fixture, _ana);
      final heldToken = server.lastIssuedRefreshToken;
      await fixture.auth.setNewPassword(_newPassword);

      final cancelled = await fixture.auth.cancelPasswordReset();

      expect(cancelled.data, isA<SignedOut>());
      expect(
        server.revocationRequests.map((form) => form['token']),
        contains(heldToken),
      );
      expect(await fixture.storedSession(), isNull);
    });

    // TEST_CHARTER
    // Requirement: abandoning only the step-up challenge goes back to the
    // new password, the session still held.
    // Oracle: the state after `cancelChallenge`, and the password set next.
    // Risk edge: the resting state of a held session read as `SignedIn`.
    // Layer: integration against the fake LoginFlow.
    // Counterfactual: `_restingState` ignoring the held reset.
    test(
      'cancelChallenge on the step-up -> back to the new password',
      () async {
        final (fixture, states) = await started(
          passkey: FakePasskeyAuthenticator(),
        );
        await codeAccepted(fixture, _ana);
        await fixture.auth.setNewPassword(_newPassword);

        final back = await fixture.auth.cancelChallenge();

        expect(back.data, const AwaitingNewPassword(email: _ana));
        await pumpEventQueue();
        expect(states.whereType<SignedIn>(), isEmpty);
      },
    );
  });

  // TEST_CHARTER
  // Requirement: a signed-in person does not reset; they change the
  // password.
  // Oracle: the public `Result`, no challenge request sent.
  // Risk edge: a reset replacing a live session.
  // Layer: integration against the fake LoginFlow.
  // Counterfactual: starting the reset regardless.
  test('started while signed in -> AlreadySignedIn', () async {
    final (fixture, _) = await started();
    await fixture.auth.signInWithPassword(
      loginHint: _luz,
      password: _luzPassword,
    );
    final requestsBefore = server.challengeRequests.length;

    final refused = await fixture.auth.startPasswordReset(_luz);

    expect(refused.errorOrNull, const AlreadySignedIn());
    expect(server.challengeRequests, hasLength(requestsBefore));
  });

  // TEST_CHARTER
  // Requirement: the browser-based reset is gone from the library: no
  // `resetPassword`, no `intent=password_reset` request anywhere in `lib/`.
  // Oracle: the library sources.
  // Risk edge: a legacy path left behind that still opens the browser.
  // Layer: source check (the removed API cannot be called from a test).
  // Counterfactual: keeping `resetPassword` or `PasswordResetInput`.
  test('the browser reset is gone from the library', () {
    final sources = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith('.dart'))
        .map((file) => file.readAsStringSync());

    for (final source in sources) {
      expect(source, isNot(contains('resetPassword(')));
      expect(source, isNot(contains('PasswordResetInput')));
      expect(source, isNot(contains("'intent'")));
    }
  });
}
