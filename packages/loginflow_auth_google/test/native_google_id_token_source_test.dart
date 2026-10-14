import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loginflow_auth/loginflow_auth_core.dart';
import 'package:loginflow_auth_google/loginflow_auth_google.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  const prompt = UpstreamPrompt(
    provider: UpstreamProvider.google,
    nonce: 'server-nonce',
    clientId: 'web-client.apps.googleusercontent.com',
  );

  tearDown(
    () => messenger.setMockMethodCallHandler(
      NativeGoogleIdTokenSource.channel,
      null,
    ),
  );

  test('sends the server nonce and client ID to the platform', () async {
    MethodCall? received;
    messenger.setMockMethodCallHandler(NativeGoogleIdTokenSource.channel, (
      call,
    ) async {
      received = call;
      return 'google.id.token';
    });

    final token = await const NativeGoogleIdTokenSource().obtainIdToken(prompt);

    expect(token.data, 'google.id.token');
    final arguments = received?.arguments as Map<Object?, Object?>;
    expect(arguments['nonce'], 'server-nonce');
    expect(arguments['serverClientId'], prompt.clientId);
  });

  test('a dismissed sheet is a typed cancellation', () async {
    messenger.setMockMethodCallHandler(
      NativeGoogleIdTokenSource.channel,
      (call) async => throw PlatformException(code: 'CANCELLED'),
    );

    final token = await const NativeGoogleIdTokenSource().obtainIdToken(prompt);

    expect(
      token.errorOrNull,
      const UpstreamFailed(
        provider: UpstreamProvider.google,
        reason: UpstreamFailureReason.cancelled,
      ),
    );
  });
}
