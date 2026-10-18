import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loginflow_auth/loginflow_auth_core.dart';
import 'package:loginflow_auth/src/platform/bindings/native_platform_bindings.dart';
import 'package:loginflow_auth/src/platform/linux/linux_dpop_key_store.dart';
import 'package:loginflow_auth/src/platform/linux/linux_session_store.dart';
import 'package:loginflow_auth/src/platform/linux/loopback_user_agent.dart';

import '../support/fake_login_flow_server.dart';
import '../support/test_signing_keys.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const secretService = MethodChannel(
    'plugins.it_nomads.com/flutter_secure_storage',
  );
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  final keyring = <String, String>{};
  final config = LoginFlowConfig(
    issuer: Uri.parse('https://login.fake.test'),
    clientId: 'app-one',
    redirectUri: Uri.parse('http://127.0.0.1:8765/oauth/callback'),
    enableDpop: true,
  );

  setUp(() {
    keyring.clear();
    debugDefaultTargetPlatformOverride = TargetPlatform.linux;
    messenger.setMockMethodCallHandler(secretService, (call) async {
      final arguments = call.arguments as Map<Object?, Object?>;
      final key = arguments['key'] as String;
      return switch (call.method) {
        'read' => keyring[key],
        'write' => keyring[key] = arguments['value'] as String,
        'delete' => keyring.remove(key),
        _ => throw PlatformException(code: 'UNKNOWN'),
      };
    });
  });

  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    messenger.setMockMethodCallHandler(secretService, null);
  });

  test('Linux keeps the session in the Secret Service, opens the system '
      'browser on a loopback redirect, and reports passkeys unavailable '
      'without throwing', () async {
    final bindings = PlatformBindings(
      config: config,
      nativeSso: null,
      prefersEphemeralBrowserSession: false,
    );
    const session = StoredSession(
      refreshToken: 'rt_1',
      idToken: 'header.payload.signature',
      scope: 'openid offline_access',
    );

    await bindings.sessionStore.write(session);
    final restored = await PlatformBindings(
      config: config,
      nativeSso: null,
      prefersEphemeralBrowserSession: false,
    ).sessionStore.read();
    final assertion = await bindings.passkeyAuthenticator.getAssertion(
      options: const <String, Object?>{'publicKey': <String, Object?>{}},
    );

    expect(bindings.sessionStore, isA<LinuxSessionStore>());
    expect(restored.data, session);
    expect(bindings.userAgent, isA<LoopbackUserAgent>());
    expect(
      assertion.errorOrNull,
      isA<PasskeyFailed>().having(
        (error) => error.reason,
        'reason',
        PasskeyFailureReason.notSupported,
      ),
    );
  });

  test('the Linux DPoP key signs proofs the server accepts and is the same '
      'key after a restart', () async {
    final keys = TestSigningKeys.generate();
    final server = FakeLoginFlowServer.inMemory(keys)..requiresDpop = true;
    LoginFlowAuth start() => LoginFlowAuth(
      config: config.copyWith(issuer: server.issuer),
      httpClient: server.client,
      sessionStore: InMemorySessionStore(),
      pendingAuthorizationStore: InMemoryPendingAuthorizationStore(),
      dpopKeyStore: LinuxDpopKeyStore(clientId: 'app-one'),
    );

    final first = await start().signInWithPassword(
      loginHint: 'ana@example.com',
      password: 'correct-horse',
    );
    final second = await start().signInWithPassword(
      loginHint: 'ana@example.com',
      password: 'correct-horse',
    );

    expect(first.errorOrNull, isNull);
    expect(second.errorOrNull, isNull);
    expect(first.data, isA<SignedIn>());
    expect(second.data, isA<SignedIn>());
    expect(server.acceptedDpopThumbprints, hasLength(4));
    expect(server.acceptedDpopThumbprints.toSet(), hasLength(1));
  });
}
