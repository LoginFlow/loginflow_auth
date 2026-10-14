import 'package:loginflow_auth/loginflow_auth_core.dart';

import 'fake_login_flow_server.dart';

/// Stands in for ASWebAuthenticationSession / Custom Tabs: it loads the URL
/// on the fake server (which plays the hosted login page and approves) and
/// returns the redirect it receives, exactly like the real browser returns
/// the callback to the app.
class FakeBrowser implements ExternalUserAgent {
  FakeBrowser(this.server);

  final FakeLoginFlowServer server;
  final List<Uri> openedUrls = <Uri>[];
  final List<Uri> discardedCallbacks = <Uri>[];
  final List<String> expectedStates = <String>[];

  /// The callback the server really produced, before [rewriteCallback].
  Uri? originalCallback;

  /// When set, the user "closes the sheet" instead of finishing.
  bool shouldCancel = false;

  /// Behaves like the web: the page navigates away and the callback is
  /// kept in [deferredCallback] for the test to deliver later.
  bool defersCallback = false;
  Uri? deferredCallback;

  /// Rewrites the callback before returning it (e.g. to tamper `state`).
  Uri Function(Uri callback)? rewriteCallback;

  @override
  Future<Result<UserAgentOutcome, LoginFlowError>> open(
    Uri url, {
    required Uri callbackUri,
    required String expectedState,
  }) async {
    openedUrls.add(url);
    expectedStates.add(expectedState);
    if (shouldCancel) {
      return Err(const BrowserFailed(reason: BrowserFailureReason.cancelled));
    }
    final response = await server.respond(
      FakeHttpRequest(
        method: 'GET',
        uri: url,
        headers: const <String, String>{},
        body: '',
      ),
    );
    final location = response.headers['location'];
    if (location == null) {
      return Err(
        BrowserFailed(
          reason: BrowserFailureReason.failed,
          description: 'HTTP ${response.statusCode} without redirect',
        ),
      );
    }
    final callback = Uri.parse(location);
    originalCallback = callback;
    if (defersCallback) {
      deferredCallback = callback;
      return Ok(const UserAgentNavigatedAway());
    }
    return Ok(
      UserAgentCallback(uri: rewriteCallback?.call(callback) ?? callback),
    );
  }

  @override
  Future<void> discardCallback(Uri cleanUri) async {
    discardedCallbacks.add(cleanUri);
  }
}
