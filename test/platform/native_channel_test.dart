import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loginflow_auth/loginflow_auth_core.dart';
import 'package:loginflow_auth/src/platform/native/native_channel.dart';
import 'package:loginflow_auth/src/platform/native/native_session_store.dart';
import 'package:loginflow_auth/src/platform/native/native_sso_store.dart';
import 'package:loginflow_auth/src/platform/native/native_user_agent.dart';
import 'package:loginflow_auth/src/platform/native_sso_options.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  final calls = <MethodCall>[];
  final storage = <String, String>{};

  setUp(() {
    calls.clear();
    storage.clear();
    messenger.setMockMethodCallHandler(NativeChannel.channel, (call) async {
      calls.add(call);
      final arguments = call.arguments as Map<Object?, Object?>;
      final key = (arguments['key'] ?? arguments['issuer']) as String;
      return switch (call.method) {
        NativeChannel.privateRead || NativeChannel.ssoRead => storage[key],
        NativeChannel.privateWrite ||
        NativeChannel.ssoWrite => storage[key] = arguments['value'] as String,
        NativeChannel.privateDelete ||
        NativeChannel.ssoDelete => storage.remove(key),
        _ => throw PlatformException(code: 'UNKNOWN'),
      };
    });
  });

  tearDown(
    () => messenger.setMockMethodCallHandler(NativeChannel.channel, null),
  );

  test('the private session store round-trips through the channel', () async {
    final store = NativeSessionStore(
      issuer: 'https://api.loginflow.dev',
      clientId: 'app-one',
      sharedAccessGroup: 'ABCDE12345.com.acme.loginflow.sso',
    );
    const session = StoredSession(
      refreshToken: 'rt_1',
      idToken: 'header.payload.signature',
      scope: 'openid offline_access',
      isSsoBound: true,
    );

    await store.write(session);
    final restored = await store.read();
    await store.clear();

    expect(restored.data, session);
    expect((await store.read()).data, isNull);
    final write = calls.firstWhere(
      (call) => call.method == NativeChannel.privateWrite,
    );
    final arguments = write.arguments as Map<Object?, Object?>;
    expect(arguments['key'], 'session|https://api.loginflow.dev|app-one');
    expect(arguments['sharedAccessGroup'], 'ABCDE12345.com.acme.loginflow.sso');
  });

  test(
    'the SSO store sends the access group and sibling authorities',
    () async {
      const store = NativeSsoStore(
        options: NativeSsoOptions(
          appleAccessGroup: 'ABCDE12345.com.acme.loginflow.sso',
          androidSiblingAuthorities: <String>['com.acme.orders.loginflow.sso'],
        ),
      );
      final entry = SsoEntry(
        issuer: 'https://api.loginflow.dev',
        deviceSecret: 'ds_1',
        idToken: 'a.b.c',
        updatedAt: DateTime.utc(2026, 10, 15),
      );

      await store.write(entry);

      expect((await store.read(entry.issuer)).data, entry);
      final arguments = calls.first.arguments as Map<Object?, Object?>;
      expect(arguments['accessGroup'], 'ABCDE12345.com.acme.loginflow.sso');
      expect(arguments['authorities'], <String>[
        'com.acme.orders.loginflow.sso',
      ]);
    },
  );

  test('a platform storage error becomes a StorageFailure value', () async {
    messenger.setMockMethodCallHandler(
      NativeChannel.channel,
      (call) async => throw PlatformException(
        code: 'MISCONFIGURED',
        message: 'private item landed in the shared access group',
      ),
    );
    final store = NativeSessionStore(
      issuer: 'https://api.loginflow.dev',
      clientId: 'app-one',
    );

    final result = await store.read();

    expect(result.errorOrNull, isA<StorageFailure>());
  });

  test('a cancelled browser sheet becomes BrowserFailed(cancelled)', () async {
    messenger.setMockMethodCallHandler(
      NativeChannel.channel,
      (call) async =>
          throw PlatformException(code: NativeChannel.cancelledCode),
    );

    final result = await const NativeUserAgent().open(
      Uri.parse('https://api.loginflow.dev/oauth2/authorize'),
      callbackUri: Uri.parse('https://app.example.com/oauth/callback'),
      expectedState: 'state-1',
    );

    expect(
      result.errorOrNull,
      const BrowserFailed(reason: BrowserFailureReason.cancelled),
    );
  });

  test('the browser receives the callback scheme, host and path', () async {
    messenger.setMockMethodCallHandler(NativeChannel.channel, (call) async {
      calls.add(call);
      return 'com.acme.app:/oauth/callback?code=c&state=s';
    });

    final result = await const NativeUserAgent(prefersEphemeralSession: true)
        .open(
          Uri.parse('https://api.loginflow.dev/oauth2/authorize'),
          callbackUri: Uri.parse('com.acme.app:/oauth/callback'),
          expectedState: 's',
        );

    expect(
      result.data,
      UserAgentCallback(
        uri: Uri.parse('com.acme.app:/oauth/callback?code=c&state=s'),
      ),
    );
    final arguments = calls.single.arguments as Map<Object?, Object?>;
    expect(arguments['callbackScheme'], 'com.acme.app');
    expect(arguments['callbackPath'], '/oauth/callback');
    expect(arguments['prefersEphemeral'], isTrue);
    expect(arguments['state'], 's');
  });
}
