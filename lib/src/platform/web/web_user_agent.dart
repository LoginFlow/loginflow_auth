import 'package:loginflow_auth/src/core/browser/external_user_agent.dart';
import 'package:loginflow_auth/src/core/error/login_flow_error.dart';
import 'package:result_controller/result_controller.dart';
import 'package:web/web.dart' as web;

/// Top-level navigation to the authorization server: the session cookie is
/// first-party there, so SSO works across dashboard domains without
/// third-party cookies or iframes (`doc/decisions.md` D10).
final class WebUserAgent implements ExternalUserAgent {
  const WebUserAgent();

  @override
  Future<Result<UserAgentOutcome, LoginFlowError>> open(
    Uri url, {
    required Uri callbackUri,
    required String expectedState,
  }) async {
    web.window.location.assign(url.toString());
    return Ok(const UserAgentNavigatedAway());
  }

  /// Removes `code` and `state` from the address bar and history.
  @override
  Future<void> discardCallback(Uri cleanUri) async {
    web.window.history.replaceState(null, '', cleanUri.toString());
  }
}
