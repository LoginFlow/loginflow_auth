import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:loginflow_auth/loginflow_auth_core.dart';
import 'package:loginflow_auth/src/core/jose/compact_jws.dart';

import '../support/auth_fixture.dart';
import '../support/fake_login_flow_server.dart';
import '../support/test_signing_keys.dart';

const String _luz = 'luz@example.com';
const String _luzPassword = 'sea-breeze';
const String _tomas = 'tomas@example.com';
const String _tomasPassword = 'battery-staple';

/// The self-service email change (`/v1/app/email-change`,
/// `doc/server-contract.md` §19) against a fake LoginFlow that answers like
/// `email_change_handler.rs`: the person's DPoP-bound LoginFlow token, the
/// step-up the credential requires (strong with a second factor, recent
/// without), one code to the new address and — without a second factor —
/// another to the current one.
///
/// The client is `app-two`, which has exactly ONE API, like RutaFácil: its
/// session token is that API's, which the email-change door refuses.
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

  Future<AuthFixture> fixture() async {
    final created = AuthFixture.create(
      server,
      clientId: 'app-two',
      enableDpop: true,
    );
    await created.auth.initialize();
    return created;
  }

  /// Luz signs in with her password: recent, single factor.
  Future<AuthFixture> luzSignedIn() async {
    final created = await fixture();
    final signedIn = await created.auth.signInWithPassword(
      loginHint: _luz,
      password: _luzPassword,
    );
    expect(signedIn.data, isA<SignedIn>());
    return created;
  }

  /// Tomás signs in with his password and TOTP: recent and strong.
  Future<AuthFixture> tomasSignedIn() async {
    final created = await fixture();
    await created.auth.signInWithPassword(
      loginHint: _tomas,
      password: _tomasPassword,
    );
    final signedIn = await created.auth.submitTotp(
      FakeLoginFlowServer.totpCode,
    );
    expect(signedIn.data, isA<SignedIn>());
    return created;
  }

  Map<String, Object?> lastBody() =>
      jsonDecode(server.emailChangeRequests.last.body) as Map<String, Object?>;

  String? emailOf(AuthState state) => switch (state) {
    SignedIn(:final session) => session.identity.email,
    _ => null,
  };

  // TEST_CHARTER
  // Requirement: without a second factor the start answers
  // `confirm_current: true`, both codes confirm the change, and the session
  // is refreshed so its ID token carries the new email.
  // Oracle: the start's `EmailChangeStarted`, the wire bodies, the token the
  // requests present (`DPoP`, `aud` = issuer), the confirmation, and the
  // email of the `SignedIn` session afterwards.
  // Risk edge: the session token of a single-API client is refused
  // (`403 wrong_audience`); the second code is never sent; the app keeps
  // showing the old email until the next sign-in.
  // Layer: integration against the fake LoginFlow (real HTTP, real DPoP).
  // Counterfactual: no refresh after the confirmation leaves the old email
  // in the session; the session's own token instead of the LoginFlow one is
  // `wrong_audience`.
  test('without a second factor: two codes confirm the change and the '
      'session carries the new email', () async {
    final auth = (await luzSignedIn()).auth;

    final started = await auth.startEmailChange('luz.new@example.com');
    final startBody = lastBody();
    final startRequest = server.emailChangeRequests.last;
    final newCode = server.emailChangeCodeSentTo('luz.new@example.com')!;
    final currentCode = server.emailChangeCodeSentTo(_luz)!;
    final confirmed = await auth.confirmEmailChange(
      newCode,
      currentCode: currentCode,
    );

    expect(started.isOk, isTrue, reason: '$started');
    expect(started.data.confirmCurrent, isTrue);
    expect(started.data.expiresAt.isUtc, isTrue);
    expect(startBody, <String, Object?>{'new_email': 'luz.new@example.com'});
    expect(startRequest.uri.path, '/v1/app/email-change');
    final authorization = startRequest.headers['authorization']!;
    expect(authorization, startsWith('DPoP '));
    expect(
      CompactJws.parse(authorization.substring(5)).data.claims['aud'],
      server.issuerText,
    );
    expect(startRequest.headers['dpop'], isNotNull);
    expect(lastBody(), <String, Object?>{
      'code': newCode,
      'current_code': currentCode,
    });
    expect(
      server.emailChangeRequests.last.uri.path,
      '/v1/app/email-change/confirm',
    );
    expect(
      confirmed.data,
      const EmailChangeConfirmed(
        email: 'luz.new@example.com',
        isEmailVerified: true,
      ),
    );
    expect(emailOf(auth.state), 'luz.new@example.com');
  });

  // TEST_CHARTER
  // Requirement: with a second factor only the new address gets a code and
  // the confirmation sends that one alone.
  // Oracle: `confirmCurrent`, the codes the server sent, the confirmation
  // body and result.
  // Risk edge: the client asks for (or sends) a current-address code the
  // server never issued.
  // Layer: integration against the fake LoginFlow.
  // Counterfactual: always sending `current_code` fails the body assertion.
  test('with a second factor: one code, to the new address', () async {
    final auth = (await tomasSignedIn()).auth;

    final started = await auth.startEmailChange('tomas.new@example.com');
    final code = server.emailChangeCodeSentTo('tomas.new@example.com')!;
    final confirmed = await auth.confirmEmailChange(code);

    expect(started.data.confirmCurrent, isFalse);
    expect(server.sentEmailChangeCodes, hasLength(1));
    expect(lastBody(), <String, Object?>{'code': code});
    expect(confirmed.data.email, 'tomas.new@example.com');
    expect(emailOf(auth.state), 'tomas.new@example.com');
  });

  // TEST_CHARTER
  // Requirement: a credential with a second factor whose sign-in is not
  // recent and strong gets the strong RFC 9470 challenge; the library's own
  // step-up (password, then TOTP) satisfies it and the start, retried,
  // succeeds.
  // Oracle: the `StepUpRequired` requirement (`acr_values`, `max_age`,
  // `isStrongRequired`), the step-up's prompts, and the retried start.
  // Risk edge: the retry reuses the LoginFlow token cached before the
  // step-up (still stale) and loops on the challenge.
  // Layer: integration against the fake LoginFlow.
  // Counterfactual: keeping the pre-step-up LoginFlow token makes the retry
  // `StepUpRequired` again.
  test('strong step-up needed: after password and TOTP the start is '
      'retried and accepted', () async {
    final auth = (await tomasSignedIn()).auth;
    server.expireRecentAuthentications();

    final refused = await auth.startEmailChange('tomas.new@example.com');
    final requirement = (refused.errorOrNull! as StepUpRequired).requirement;
    final password = await auth.stepUp(requirement);
    final totp = await auth.submitPassword(_tomasPassword);
    final confirmed = await auth.submitTotp(FakeLoginFlowServer.totpCode);
    final retried = await auth.startEmailChange('tomas.new@example.com');

    expect(requirement.isStrongRequired, isTrue);
    expect(requirement.acrValues, <String>[
      'urn:loginflow:acr:phr',
      'urn:loginflow:acr:mfa',
    ]);
    expect(requirement.maxAge, const Duration(seconds: 300));
    expect(
      (password.data as ChallengeRequired).prompt.step,
      ChallengeStep.password,
    );
    expect((totp.data as ChallengeRequired).prompt.step, ChallengeStep.totp);
    expect(confirmed.data, isA<SignedIn>());
    expect(retried.isOk, isTrue, reason: '$retried');
    expect(retried.data.confirmCurrent, isFalse);
  });

  // TEST_CHARTER
  // Requirement: a credential without a second factor whose sign-in is not
  // recent gets the recent-only challenge (no `acr_values`); signing in
  // again with the password is enough and the retried start succeeds.
  // Oracle: the requirement (`isStrongRequired` false), the one password
  // prompt, and the retried start.
  // Risk edge: the UI demands a second factor the account does not have.
  // Layer: integration against the fake LoginFlow.
  // Counterfactual: reading every challenge as strong fails
  // `isStrongRequired`.
  test('recent sign-in needed: the password alone re-authenticates and '
      'the start is retried', () async {
    final auth = (await luzSignedIn()).auth;
    server.expireRecentAuthentications();

    final refused = await auth.startEmailChange('luz.new@example.com');
    final requirement = (refused.errorOrNull! as StepUpRequired).requirement;
    final password = await auth.stepUp(requirement);
    final confirmed = await auth.submitPassword(_luzPassword);
    final retried = await auth.startEmailChange('luz.new@example.com');

    expect(requirement.isStrongRequired, isFalse);
    expect(requirement.acrValues, isEmpty);
    expect(requirement.maxAge, const Duration(seconds: 300));
    expect(
      (password.data as ChallengeRequired).prompt.step,
      ChallengeStep.password,
    );
    expect(confirmed.data, isA<SignedIn>());
    expect(retried.data.confirmCurrent, isTrue);
  });

  // TEST_CHARTER
  // Requirement: the refusals are typed — a wrong, missing or malformed
  // code is the one generic `InvalidEmailChangeCode`, a refused address is
  // `InvalidEmailAddress`, a fourth start in the hour is `RateLimited` with
  // `Retry-After` — and a refusal leaves the session's email untouched.
  // Oracle: the returned errors and the session's email.
  // Risk edge: every refusal collapses into `ServerResponseInvalid` and the
  // UI cannot tell "wrong code" from "try later".
  // Layer: integration against the fake LoginFlow (the API's envelopes).
  // Counterfactual: mapping with the generic account-API error returns
  // `ServerResponseInvalid` for the `422`s and `INVALID_CODE`.
  test('refusals are typed: code, address and rate limit', () async {
    final auth = (await luzSignedIn()).auth;

    final malformed = await auth.startEmailChange('not-an-email');
    final same = await auth.startEmailChange('LUZ@example.com');
    await auth.startEmailChange('luz.new@example.com');
    final newCode = server.emailChangeCodeSentTo('luz.new@example.com')!;
    final currentCode = server.emailChangeCodeSentTo(_luz)!;
    final wrong = await auth.confirmEmailChange(
      newCode == '000000' ? '111111' : '000000',
      currentCode: currentCode,
    );
    final missingCurrent = await auth.confirmEmailChange(newCode);
    final notSixDigits = await auth.confirmEmailChange('12a4');
    await auth.startEmailChange('luz.second@example.com');
    await auth.startEmailChange('luz.third@example.com');
    final limited = await auth.startEmailChange('luz.fourth@example.com');

    expect(malformed.errorOrNull, const InvalidEmailAddress());
    expect(same.errorOrNull, const InvalidEmailAddress());
    expect(wrong.errorOrNull, const InvalidEmailChangeCode());
    expect(missingCurrent.errorOrNull, const InvalidEmailChangeCode());
    expect(notSixDigits.errorOrNull, const InvalidEmailChangeCode());
    expect(
      limited.errorOrNull,
      const RateLimited(retryAfter: FakeLoginFlowServer.emailChangeRetryAfter),
    );
    expect(emailOf(auth.state), _luz);
  });
}
