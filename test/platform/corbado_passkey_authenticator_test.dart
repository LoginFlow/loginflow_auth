// TEST_CHARTER
// Requirement: `CorbadoPasskeyAuthenticator` never throws and never hangs:
// every failure of the `passkeys` plugin or of the JSON it is handed
// (Corbado `AuthenticatorException`s, a rethrown `PlatformException`
// carrying a WebAuthn `DOMException` name, `FormatException`, `TypeError`,
// anything) becomes `PasskeyFailed` with a typed `PasskeyFailureReason`,
// a ceremony that never finishes resolves to `timeout`, and an explicit
// (button) ceremony is always modal — the server's `mediation:
// "conditional"` for a discoverable request is never forwarded, since a
// conditional request with no autofill field waits forever on iOS and the
// web.
// Oracle: the `Result` the adapter returns and the request the plugin's
// platform half actually received (`FakePasskeysPlatform` sits UNDER the
// real Corbado `PasskeyAuthenticator`, so the plugin's own code -> exception
// translation runs as on a device).
// Risk edge: codes Corbado does not translate (`SecurityError`,
// `InvalidStateError`, `AbortError`, Android `android-unhandled:` DOM
// types) are rethrown by the plugin as a raw `PlatformException` — the
// historic adapter caught only `AuthenticatorException`, so these escaped
// to the caller as exceptions.
// Layer: platform adapter against the real plugin Dart code with a fake
// platform implementation (the native side cannot run in a VM test).
// Counterfactual: removing the catch-all, the timeout or the mediation
// override makes the corresponding test fail (uncaught exception, test
// timeout, `MediationType.Conditional` seen by the platform).

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loginflow_auth/loginflow_auth.dart';
import 'package:passkeys/authenticator.dart' as corbado;
import 'package:passkeys/types.dart' as corbado;
import 'package:passkeys_platform_interface/passkeys_platform_interface.dart';

import '../support/fake_passkeys_platform.dart';

void main() {
  late FakePasskeysPlatform platform;

  setUp(() {
    platform = FakePasskeysPlatform();
    PasskeysPlatform.instance = platform;
  });

  CorbadoPasskeyAuthenticator adapter({
    Duration ceremonyTimeout =
        CorbadoPasskeyAuthenticator.defaultCeremonyTimeout,
  }) => CorbadoPasskeyAuthenticator(
    authenticator: corbado.PasskeyAuthenticator(),
    ceremonyTimeout: ceremonyTimeout,
  );

  Map<String, Object?> assertionOptions({
    String? mediation,
    Object? timeout = 60000,
  }) => <String, Object?>{
    'publicKey': <String, Object?>{
      'challenge': 'Y2hhbGxlbmdl',
      'rpId': 'acme.id.loginflow.dev',
      'userVerification': 'required',
      'timeout': timeout,
    },
    'mediation': ?mediation,
  };

  Map<String, Object?> creationOptions({
    bool hasRelyingParty = true,
  }) => <String, Object?>{
    'publicKey': <String, Object?>{
      'challenge': 'Y2hhbGxlbmdl',
      if (hasRelyingParty)
        'rp': <String, Object?>{'id': 'acme.id.loginflow.dev', 'name': 'Acme'},
      'user': <String, Object?>{
        'id': 'dXNlcg',
        'name': 'ana@example.com',
        'displayName': 'Ana Ruiz',
      },
      'pubKeyCredParams': <Object?>[
        <String, Object?>{'type': 'public-key', 'alg': -7},
      ],
    },
  };

  Matcher failedWith(PasskeyFailureReason reason) =>
      isA<PasskeyFailed>().having((error) => error.reason, 'reason', reason);

  group('getAssertion maps every plugin failure to a reason', () {
    final cases = <String, PasskeyFailureReason>{
      'cancelled': PasskeyFailureReason.userCancelled,
      'NotAllowedError': PasskeyFailureReason.userCancelled,
      'AbortError': PasskeyFailureReason.userCancelled,
      'suppressed': PasskeyFailureReason.userCancelled,
      'SecurityError': PasskeyFailureReason.securityError,
      'NotSupportedError': PasskeyFailureReason.notSupported,
      'deviceNotSupported': PasskeyFailureReason.notSupported,
      'domain-not-associated': PasskeyFailureReason.domainNotAssociated,
      'no-credentials-available': PasskeyFailureReason.noCredentialsAvailable,
      'android-timeout': PasskeyFailureReason.timeout,
      'android-unhandled: '
          'androidx.credentials.TYPE_GET_PUBLIC_KEY_CREDENTIAL_DOM_EXCEPTION'
          '/androidx.credentials.TYPE_SECURITY_ERROR': PasskeyFailureReason
          .securityError,
      'ios-unhandled-WKErrorDomain': PasskeyFailureReason.unknown,
      'parse-error': PasskeyFailureReason.invalidResponse,
      'a-code-from-a-future-plugin': PasskeyFailureReason.unknown,
    };
    for (final MapEntry(key: code, value: reason) in cases.entries) {
      test('PlatformException "$code" -> ${reason.name}', () async {
        platform.failure = PlatformException(code: code, message: 'detail');

        final result = await adapter().getAssertion(
          options: assertionOptions(),
        );

        expect(result.errorOrNull, failedWith(reason));
      });
    }

    test(
      'a rethrown platform error keeps its original code and message',
      () async {
        platform.failure = PlatformException(
          code: 'SecurityError',
          message: 'The RP ID is not valid for this origin.',
        );

        final result = await adapter().getAssertion(
          options: assertionOptions(),
        );

        expect(
          result.errorOrNull,
          const PasskeyFailed(
            reason: PasskeyFailureReason.securityError,
            code: 'SecurityError',
            description: 'The RP ID is not valid for this origin.',
          ),
        );
      },
    );

    test('a FormatException from the platform -> invalidResponse', () async {
      platform.failure = const FormatException('Unexpected character');

      final result = await adapter().getAssertion(options: assertionOptions());

      expect(
        result.errorOrNull,
        failedWith(PasskeyFailureReason.invalidResponse),
      );
    });

    test(
      'options of the wrong JSON type (TypeError) -> invalidResponse',
      () async {
        final result = await adapter().getAssertion(
          options: assertionOptions(timeout: '60000'),
        );

        expect(
          result.errorOrNull,
          failedWith(PasskeyFailureReason.invalidResponse),
        );
        expect(platform.authenticateRequests, isEmpty);
      },
    );

    test('any other error -> unknown, never an exception', () async {
      platform.failure = StateError('plugin bug');

      final result = await adapter().getAssertion(options: assertionOptions());

      expect(result.errorOrNull, failedWith(PasskeyFailureReason.unknown));
    });
  });

  group('createCredential maps every plugin failure to a reason', () {
    final cases = <String, PasskeyFailureReason>{
      'cancelled': PasskeyFailureReason.userCancelled,
      'InvalidStateError': PasskeyFailureReason.alreadyRegistered,
      'exclude-credentials-match': PasskeyFailureReason.alreadyRegistered,
      'android-unhandled: '
          'androidx.credentials.TYPE_CREATE_PUBLIC_KEY_CREDENTIAL_DOM_EXCEPTION'
          '/androidx.credentials.TYPE_INVALID_STATE_ERROR': PasskeyFailureReason
          .alreadyRegistered,
      'SecurityError': PasskeyFailureReason.securityError,
      'domain-not-associated': PasskeyFailureReason.domainNotAssociated,
    };
    for (final MapEntry(key: code, value: reason) in cases.entries) {
      test('PlatformException "$code" -> ${reason.name}', () async {
        platform.failure = PlatformException(code: code, message: 'detail');

        final result = await adapter().createCredential(
          options: creationOptions(),
        );

        expect(result.errorOrNull, failedWith(reason));
      });
    }

    test('options without "rp" (FormatException) -> invalidResponse', () async {
      final result = await adapter().createCredential(
        options: creationOptions(hasRelyingParty: false),
      );

      expect(
        result.errorOrNull,
        failedWith(PasskeyFailureReason.invalidResponse),
      );
      expect(platform.registerRequests, isEmpty);
    });

    test('a successful ceremony returns the credential JSON', () async {
      final result = await adapter().createCredential(
        options: creationOptions(),
      );

      expect(result.data['id'], 'Y3JlZGVudGlhbA');
    });
  });

  group('ceremony timeout', () {
    test('a ceremony that never finishes resolves to timeout and is '
        'cancelled on the platform', () async {
      platform.isHanging = true;

      final result = await adapter(
        ceremonyTimeout: const Duration(milliseconds: 20),
      ).getAssertion(options: assertionOptions());

      expect(result.errorOrNull, failedWith(PasskeyFailureReason.timeout));
      expect(
        platform.cancelCount,
        2,
        reason:
            'one cancel the plugin issues before every ceremony, one from '
            'the timeout dismissing the stuck sheet',
      );
    }, timeout: const Timeout(Duration(seconds: 5)));

    test('enrollment times out the same way', () async {
      platform.isHanging = true;

      final result = await adapter(
        ceremonyTimeout: const Duration(milliseconds: 20),
      ).createCredential(options: creationOptions());

      expect(result.errorOrNull, failedWith(PasskeyFailureReason.timeout));
    }, timeout: const Timeout(Duration(seconds: 5)));
  });

  group('mediation', () {
    test('the server\'s "conditional" mediation never reaches the platform: '
        'an explicit ceremony is always modal', () async {
      final result = await adapter().getAssertion(
        options: assertionOptions(mediation: 'conditional'),
      );

      expect(result.data['id'], 'Y3JlZGVudGlhbA');
      expect(
        platform.authenticateRequests.single.mediation,
        corbado.MediationType.Optional,
      );
    });
  });
}
