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

  group('redirect_to_web (first-party-apps §5.2.2.1.1)', () {
    test('Microsoft opens the system browser with the pushed request_uri '
        'and redeems the code with redirect_uri', () async {
      final fixture = AuthFixture.create(server);
      await fixture.auth.initialize();

      final result = await fixture.auth.signInWithMicrosoft();

      expect(result.data, isA<SignedIn>());
      final opened = fixture.browser.openedUrls.single;
      expect(opened.path, '/oauth2/authorize');
      expect(opened.queryParameters.keys, <String>['client_id', 'request_uri']);
      final challenge = server.challengeRequests.single;
      expect(challenge['upstream_provider'], 'microsoft');
      expect(
        challenge['redirect_uri'],
        'https://app.example.com/oauth/callback',
      );
      expect(challenge['state'], isNotEmpty);
      final redeem = server.tokenRequests.single;
      expect(redeem['redirect_uri'], 'https://app.example.com/oauth/callback');
      expect(
        fixture.browser.discardedCallbacks.single,
        Uri.parse('https://app.example.com/oauth/callback'),
      );
      expect((await fixture.storedSession())?.isBrowserSessionUsed, isTrue);
    });

    test('Google without a native source goes through the browser', () async {
      final fixture = AuthFixture.create(server);
      await fixture.auth.initialize();

      final result = await fixture.auth.signInWithGoogle();

      expect(result.data, isA<SignedIn>());
      expect(server.challengeRequests.single['upstream_flow'], 'browser');
    });

    test('sign-up uses prompt=create and continues in the browser', () async {
      final fixture = AuthFixture.create(server);
      await fixture.auth.initialize();

      final result = await fixture.auth.signUp();

      expect(result.data, isA<SignedIn>());
      expect(server.challengeRequests.single['prompt'], 'create');
    });

    test('a cancelled browser sheet returns to the resting state', () async {
      final fixture = AuthFixture.create(server);
      fixture.browser.shouldCancel = true;
      await fixture.auth.initialize();

      final result = await fixture.auth.signInWithMicrosoft();

      expect(
        result.errorOrNull,
        const BrowserFailed(reason: BrowserFailureReason.cancelled),
      );
      expect(fixture.auth.state, const SignedOut());
    });

    test('a forged state is rejected before any code is redeemed and the '
        'pending request is kept (doc/decisions.md D17)', () async {
      final fixture = AuthFixture.create(server);
      fixture.browser.rewriteCallback = (callback) => callback.replace(
        queryParameters: <String, String>{
          ...callback.queryParameters,
          'state': 'forged',
        },
      );
      await fixture.auth.initialize();

      final result = await fixture.auth.signInWithMicrosoft();

      expect(
        result.errorOrNull,
        const AuthorizationResponseRejected(
          problem: AuthorizationResponseProblem.stateMismatch,
        ),
      );
      expect(server.tokenRequests, isEmpty);
      expect(
        fixture.browser.expectedStates.single,
        server.challengeRequests.single['state'],
      );
      final real = await fixture.auth.completeBrowserRedirect(
        fixture.browser.originalCallback!,
      );
      expect(real.data, isA<SignedIn>());
    });

    test('a callback from another issuer (RFC 9207) is rejected', () async {
      final fixture = AuthFixture.create(server);
      fixture.browser.rewriteCallback = (callback) => callback.replace(
        queryParameters: <String, String>{
          ...callback.queryParameters,
          'iss': 'https://attacker.example',
        },
      );
      await fixture.auth.initialize();

      final result = await fixture.auth.signInWithMicrosoft();

      expect(
        result.errorOrNull,
        const AuthorizationResponseRejected(
          problem: AuthorizationResponseProblem.issuerMismatch,
        ),
      );
      expect(server.tokenRequests, isEmpty);
    });

    test('without a system browser the step fails as unavailable', () async {
      final fixture = AuthFixture.create(server, hasBrowser: false);
      await fixture.auth.initialize();

      final result = await fixture.auth.signInWithMicrosoft();

      expect(
        result.errorOrNull,
        isA<BrowserFailed>().having(
          (error) => error.reason,
          'reason',
          BrowserFailureReason.unavailable,
        ),
      );
    });
  });

  group('Browser sign-in (web top-level redirect)', () {
    test(
      'prompt=none without a browser session reports login_required',
      () async {
        final fixture = AuthFixture.create(server);
        await fixture.auth.initialize();

        final silent = await fixture.auth.signInWithBrowser(
          prompt: AuthorizationPrompt.none,
        );

        expect(
          silent.data,
          const SignedOut(reason: SignOutReason.loginRequired),
        );

        final interactive = await fixture.auth.signInWithBrowser();
        expect(interactive.data, isA<SignedIn>());
        final authorize = fixture.browser.openedUrls.last.queryParameters;
        expect(authorize['response_type'], 'code');
        expect(authorize['code_challenge_method'], 'S256');
        expect(authorize['nonce'], isNotEmpty);
        expect(
          authorize['redirect_uri'],
          'https://app.example.com/oauth/callback',
        );
      },
    );

    test(
      'prompt=none signs in silently when the browser session exists',
      () async {
        server.hasBrowserSession = true;
        final fixture = AuthFixture.create(server);
        await fixture.auth.initialize();

        final silent = await fixture.auth.signInWithBrowser(
          prompt: AuthorizationPrompt.none,
        );

        expect(silent.data, isA<SignedIn>());
      },
    );
  });

  group('Callback matching (doc/decisions.md D17)', () {
    test('a forged or foreign callback is ignored and the real one still '
        'completes', () async {
      final fixture = AuthFixture.create(server);
      fixture.browser.defersCallback = true;
      await fixture.auth.initialize();
      await fixture.auth.signInWithMicrosoft();
      final real = fixture.browser.deferredCallback!;

      final forged = await fixture.auth.completeBrowserRedirect(
        real.replace(
          queryParameters: <String, String>{
            ...real.queryParameters,
            'state': 'forged',
          },
        ),
      );
      final foreign = await fixture.auth.completeBrowserRedirect(
        Uri.parse('https://evil.example/oauth/callback')
            .replace(queryParameters: real.queryParameters),
      );

      expect(
        forged.errorOrNull,
        const AuthorizationResponseRejected(
          problem: AuthorizationResponseProblem.stateMismatch,
        ),
      );
      expect(foreign.errorOrNull, isA<AuthorizationResponseRejected>());
      expect(fixture.auth.state, const AwaitingBrowser());
      expect(server.tokenRequests, isEmpty);

      final completed = await fixture.auth.completeBrowserRedirect(real);
      expect(completed.data, isA<SignedIn>());
    });

    test('a callback for a request older than 10 minutes is refused', () async {
      final fixture = AuthFixture.create(server);
      fixture.browser.defersCallback = true;
      await fixture.auth.initialize();
      await fixture.auth.signInWithMicrosoft();
      fixture.clock.advance(const Duration(minutes: 11));

      final result = await fixture.auth.completeBrowserRedirect(
        fixture.browser.deferredCallback!,
      );

      expect(
        result.errorOrNull,
        const AuthorizationResponseRejected(
          problem: AuthorizationResponseProblem.requestExpired,
        ),
      );
      expect(server.tokenRequests, isEmpty);
    });

    test('a callback without iss is rejected (RFC 9207 §2.4)', () async {
      final fixture = AuthFixture.create(server);
      fixture.browser.rewriteCallback = (callback) => callback.replace(
        queryParameters: <String, String>{
          for (final MapEntry(:key, :value) in callback.queryParameters.entries)
            if (key != 'iss') key: value,
        },
      );
      await fixture.auth.initialize();

      final result = await fixture.auth.signInWithMicrosoft();

      expect(
        result.errorOrNull,
        const AuthorizationResponseRejected(
          problem: AuthorizationResponseProblem.issuerMismatch,
        ),
      );
      expect(server.tokenRequests, isEmpty);
    });
  });
}
