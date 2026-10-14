import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:loginflow_auth/loginflow_auth_core.dart';

import '../support/auth_fixture.dart';
import '../support/failing_write_session_store.dart';
import '../support/fake_login_flow_server.dart';
import '../support/gated_write_session_store.dart';
import '../support/test_signing_keys.dart';

void main() {
  late TestSigningKeys keys;
  late FakeLoginFlowServer server;

  setUpAll(() => keys = TestSigningKeys.generate());

  setUp(() async => server = await FakeLoginFlowServer.start(keys));

  tearDown(() => server.close());

  Future<AuthFixture> signedInFixture({
    InMemorySessionStore? sessionStore,
  }) async {
    final fixture = AuthFixture.create(server, sessionStore: sessionStore);
    await fixture.auth.initialize();
    await fixture.auth.signInWithPassword(
      loginHint: 'ana@example.com',
      password: 'correct-horse',
    );
    return fixture;
  }

  group('Refresh with rotation (RFC 9700 §4.14.2)', () {
    test('an expired access token is refreshed and the new refresh token '
        'is persisted', () async {
      final fixture = await signedInFixture();
      final firstAccess = (await fixture.auth.accessToken()).data;
      final firstRefresh = (await fixture.storedSession())?.refreshToken;
      fixture.clock.advance(const Duration(minutes: 15));

      final secondAccess = (await fixture.auth.accessToken()).data;

      expect(secondAccess, isNot(firstAccess));
      final refresh = server.tokenRequests.last;
      expect(refresh['grant_type'], 'refresh_token');
      expect(refresh['refresh_token'], firstRefresh);
      final rotated = (await fixture.storedSession())?.refreshToken;
      expect(rotated, isNot(firstRefresh));
      expect(fixture.auth.state, isA<SignedIn>());
    });

    test('concurrent callers share one refresh request', () async {
      final fixture = await signedInFixture();
      fixture.clock.advance(const Duration(minutes: 15));

      final tokens = await Future.wait(<Future<Result<String, LoginFlowError>>>[
        fixture.auth.accessToken(),
        fixture.auth.accessToken(),
        fixture.auth.accessToken(),
      ]);

      expect(server.refreshRequestCount(), 1);
      expect(tokens.map((token) => token.data).toSet(), hasLength(1));
    });

    test(
      'a reused refresh token revokes the family and the library logs out',
      () async {
        final store = InMemorySessionStore();
        final fixture = await signedInFixture(sessionStore: store);
        final staleRefresh = (await fixture.storedSession())!.refreshToken;
        fixture.clock.advance(const Duration(minutes: 15));
        await fixture.auth.accessToken();

        // A copy of the app restored from an old backup presents the
        // already-rotated token: the server sees reuse and revokes the family.
        final stale = InMemorySessionStore();
        await stale.write(
          (await fixture.storedSession())!.copyWith(refreshToken: staleRefresh),
        );
        final clone = AuthFixture.create(server, sessionStore: stale);
        await clone.auth.initialize();
        final cloneResult = await clone.auth.accessToken();
        expect(cloneResult.errorOrNull, const SessionRevoked());

        fixture.clock.advance(const Duration(minutes: 15));
        final result = await fixture.auth.accessToken();

        expect(result.errorOrNull, const SessionRevoked());
        expect(
          fixture.auth.state,
          const SignedOut(reason: SignOutReason.sessionRevoked),
        );
        expect(await fixture.storedSession(), isNull);
        expect(
          (await fixture.auth.accessToken()).errorOrNull,
          const NotSignedIn(),
        );
      },
    );

    test('insufficient_authorization on refresh asks the user to '
        're-authenticate', () async {
      final fixture = await signedInFixture();
      server.requiresReauthenticationOnRefresh = true;
      fixture.clock.advance(const Duration(minutes: 15));

      final result = await fixture.auth.accessToken();

      expect(result.errorOrNull, const ReauthenticationRequired());
      expect(
        fixture.auth.state,
        isA<ChallengeRequired>()
            .having(
              (state) => state.purpose,
              'purpose',
              ChallengePurpose.reauthentication,
            )
            .having(
              (state) => state.prompt.step,
              'step',
              ChallengeStep.emailOtp,
            ),
      );

      final done = await fixture.auth.submitEmailOtp(
        FakeLoginFlowServer.emailOtpCode,
      );
      expect(done.data, isA<SignedIn>());
      final reauthRequest = server.challengeRequests.last;
      expect(reauthRequest['auth_session'], isNotNull);
      expect(reauthRequest['code_challenge'], isNotNull);
    });

    test(
      'a restarted app restores the session and refreshes on demand',
      () async {
        final store = InMemorySessionStore();
        await signedInFixture(sessionStore: store);
        final restarted = AuthFixture.create(server, sessionStore: store);

        final initialized = await restarted.auth.initialize();

        expect(initialized.data, isA<SignedIn>());
        expect((await restarted.auth.accessToken()).isOk, isTrue);
        expect(server.refreshRequestCount(), 1);
      },
    );
  });

  group('Refresh racing a sign-out (doc/decisions.md D9)', () {
    Future<void> untilRefreshArrives() async {
      while (server.refreshRequestCount() == 0) {
        await Future<void>.delayed(const Duration(milliseconds: 1));
      }
    }

    test('tokens that arrive after sign-out are never persisted and are '
        'revoked', () async {
      final fixture = await signedInFixture();
      fixture.clock.advance(const Duration(minutes: 15));
      final gate = Completer<void>();
      server.refreshResponseGate = gate;

      final refreshing = fixture.auth.accessToken();
      await untilRefreshArrives();
      await fixture.auth.signOut(SignOutScope.app);
      final lateToken = server.lastIssuedRefreshToken;
      gate.complete();
      final result = await refreshing;

      expect(result.isErr, isTrue);
      expect(await fixture.storedSession(), isNull);
      expect(
        fixture.auth.state,
        const SignedOut(reason: SignOutReason.userRequested),
      );
      expect(
        server.revocationRequests.map((request) => request['token']),
        contains(lateToken),
      );
      expect(
        (await fixture.auth.accessToken()).errorOrNull,
        const NotSignedIn(),
      );
    });

    test('a late invalid_grant does not end the next user session', () async {
      final fixture = await signedInFixture();
      fixture.clock.advance(const Duration(minutes: 15));
      final gate = Completer<void>();
      server
        ..refreshResponseGate = gate
        ..rejectNextRefresh = true;

      final refreshing = fixture.auth.accessToken();
      await untilRefreshArrives();
      await fixture.auth.signOut(SignOutScope.app);
      await fixture.auth.signInWithPassword(
        loginHint: 'tomas@example.com',
        password: 'battery-staple',
      );
      await fixture.auth.submitTotp(FakeLoginFlowServer.totpCode);
      final newSession = await fixture.storedSession();
      gate.complete();
      await refreshing;

      expect(
        (fixture.auth.state as SignedIn).session.identity.subject,
        'cu_tomas',
      );
      expect(await fixture.storedSession(), newSession);
    });
  });

  test('a rotated refresh token that cannot be persisted ends the session '
      'and is revoked', () async {
    final store = FailingWriteSessionStore();
    final fixture = AuthFixture.create(server, sessionStore: store);
    await fixture.auth.initialize();
    await fixture.auth.signInWithPassword(
      loginHint: 'ana@example.com',
      password: 'correct-horse',
    );
    fixture.clock.advance(const Duration(minutes: 15));
    store.failsWrites = true;

    final result = await fixture.auth.accessToken();

    expect(result.errorOrNull, isA<StorageFailure>());
    expect(
      fixture.auth.state,
      const SignedOut(reason: SignOutReason.sessionRevoked),
    );
    expect(
      server.revocationRequests.map((request) => request['token']),
      contains(server.lastIssuedRefreshToken),
    );
    expect((await fixture.auth.accessToken()).errorOrNull, const NotSignedIn());
  });

  group('Late challenge and code responses (doc/decisions.md D9)', () {
    Future<void> until(bool Function() condition) async {
      while (!condition()) {
        await Future<void>.delayed(const Duration(milliseconds: 1));
      }
    }

    test(
      'a step-up code redeemed after sign-out is discarded and revoked',
      () async {
        final fixture = await signedInFixture();
        await fixture.auth.stepUp(
          const StepUpRequirement(acrValues: <String>['mfa']),
        );
        final gate = Completer<void>();
        server.codeResponseGate = gate;
        final codeRequests = server.tokenRequests.length;

        final stepping = fixture.auth.submitTotp(FakeLoginFlowServer.totpCode);
        await until(() => server.tokenRequests.length > codeRequests);
        await fixture.auth.signOut(SignOutScope.app);
        final lateToken = server.lastIssuedRefreshToken;
        gate.complete();
        final result = await stepping;

        expect(result.isErr, isTrue);
        expect(
          fixture.auth.state,
          const SignedOut(reason: SignOutReason.userRequested),
        );
        expect(await fixture.storedSession(), isNull);
        expect(
          server.revocationRequests.map((request) => request['token']),
          contains(lateToken),
        );
      },
    );

    test(
      'a challenge answer that arrives after cancel does not revive it',
      () async {
        final fixture = AuthFixture.create(server);
        await fixture.auth.initialize();
        await fixture.auth.requestEmailOtp(loginHint: 'ana@example.com');
        final gate = Completer<void>();
        server.challengeResponseGate = gate;
        final sent = server.challengeRequests.length;

        final submitting = fixture.auth.submitEmailOtp('000000');
        await until(() => server.challengeRequests.length > sent);
        await fixture.auth.cancelChallenge();
        gate.complete();
        final result = await submitting;

        expect(result.errorOrNull, const NoChallengeInProgress());
        expect(fixture.auth.state, const SignedOut());
        expect(
          (await fixture.auth.submitEmailOtp('424242')).errorOrNull,
          const NoChallengeInProgress(),
        );
      },
    );
  });

  test('a sign-out while new tokens are being persisted wins', () async {
    final store = GatedWriteSessionStore();
    final fixture = AuthFixture.create(server, sessionStore: store);
    await fixture.auth.initialize();
    final gate = Completer<void>();
    store.gate = gate;

    final signingIn = fixture.auth.signInWithPassword(
      loginHint: 'ana@example.com',
      password: 'correct-horse',
    );
    while (!store.isWriteHeld) {
      await Future<void>.delayed(const Duration(milliseconds: 1));
    }
    await fixture.auth.signOut(SignOutScope.app);
    final lateToken = server.lastIssuedRefreshToken;
    gate.complete();
    final result = await signingIn;

    expect(result.isErr, isTrue);
    expect(
      fixture.auth.state,
      const SignedOut(reason: SignOutReason.userRequested),
    );
    expect(await fixture.storedSession(), isNull);
    expect(
      server.revocationRequests.map((request) => request['token']),
      contains(lateToken),
    );
    expect((await fixture.auth.accessToken()).errorOrNull, const NotSignedIn());
  });
}
