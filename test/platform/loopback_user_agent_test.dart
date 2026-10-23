import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:loginflow_auth/loginflow_auth_core.dart';
import 'package:loginflow_auth/src/platform/linux/loopback_user_agent.dart';

/// Real loopback sockets, no Flutter binding: the binding's HTTP overrides
/// would answer every client request with a 400.
void main() {
  Future<int> freePort() async {
    final socket = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    final port = socket.port;
    await socket.close();
    return port;
  }

  Future<int> navigate(Uri uri) async {
    final client = HttpClient();
    final request = await client.getUrl(uri);
    final response = await request.close();
    await response.drain<void>();
    client.close();
    return response.statusCode;
  }

  test('the browser returns to the loopback redirect URI; a navigation with '
      'another state is refused and the wait goes on', () async {
    final port = await freePort();
    final callbackUri = Uri.parse('http://127.0.0.1:$port/oauth/callback');
    final navigations = <int>[];
    final userAgent = LoopbackUserAgent(
      launch: (url) async {
        navigations
          ..add(
            await navigate(callbackUri.replace(query: 'code=x&state=forged')),
          )
          ..add(await navigate(callbackUri.replace(query: 'code=c1&state=s1')));
        return true;
      },
    );

    final outcome = await userAgent.open(
      Uri.parse('https://login.example.com/oauth2/authorize?client_id=app'),
      callbackUri: callbackUri,
      expectedState: 's1',
    );

    expect(navigations, <int>[HttpStatus.notFound, HttpStatus.ok]);
    expect(
      outcome.data,
      UserAgentCallback(uri: callbackUri.replace(query: 'code=c1&state=s1')),
    );
  });

  test('the completion page names no product: the library is white-label '
      'and the tab is the only text the user reads there', () async {
    final port = await freePort();
    final callbackUri = Uri.parse('http://127.0.0.1:$port/oauth/callback');
    var page = '';
    final userAgent = LoopbackUserAgent(
      launch: (url) async {
        final client = HttpClient();
        final request = await client.getUrl(
          callbackUri.replace(query: 'code=c1&state=s1'),
        );
        final response = await request.close();
        page = await response.transform(const SystemEncoding().decoder).join();
        client.close();
        return true;
      },
    );

    await userAgent.open(
      Uri.parse('https://login.example.com/oauth2/authorize?client_id=app'),
      callbackUri: callbackUri,
      expectedState: 's1',
    );

    expect(page, contains('<title>'));
    expect(page.toLowerCase(), isNot(contains('loginflow')));
  });

  test(
    'a redirect URI that is not a loopback literal is unavailable',
    () async {
      final userAgent = LoopbackUserAgent(launch: (_) async => true);

      final outcome = await userAgent.open(
        Uri.parse('https://login.example.com/oauth2/authorize'),
        callbackUri: Uri.parse('https://app.example.com/oauth/callback'),
        expectedState: 's1',
      );

      expect(
        outcome.errorOrNull,
        isA<BrowserFailed>().having(
          (error) => error.reason,
          'reason',
          BrowserFailureReason.unavailable,
        ),
      );
    },
  );
}
