import 'package:loginflow_auth/src/core/browser/external_user_agent.dart';
import 'package:loginflow_auth/src/core/error/browser_failure_reason.dart';
import 'package:loginflow_auth/src/core/error/login_flow_error.dart';
import 'package:loginflow_auth/src/platform/native/native_channel.dart';
import 'package:result_controller/result_controller.dart';

/// [ExternalUserAgent] over ASWebAuthenticationSession (iOS/macOS) and
/// Custom Tabs (Android). Never a WebView (RFC 8252 §8.12).
final class NativeUserAgent implements ExternalUserAgent {
  const NativeUserAgent({this.prefersEphemeralSession = false});

  /// iOS/macOS `prefersEphemeralWebBrowserSession`: `true` shares no cookies
  /// with Safari (no browser SSO, no consent alert). Set it deliberately
  /// (APPLE-ASWAS-EPHEMERAL).
  final bool prefersEphemeralSession;

  @override
  Future<Result<UserAgentOutcome, LoginFlowError>> open(
    Uri url, {
    required Uri callbackUri,
    required String expectedState,
  }) async {
    final callback = await NativeChannel.invokeBrowser(<String, Object?>{
      'url': url.toString(),
      'callbackScheme': callbackUri.scheme,
      'callbackHost': callbackUri.host,
      'callbackPath': callbackUri.path,
      'state': expectedState,
      'prefersEphemeral': prefersEphemeralSession,
    });
    return callback.flatMap((value) {
      final uri = value == null ? null : Uri.tryParse(value);
      return uri == null
          ? Err(
              const BrowserFailed(
                reason: BrowserFailureReason.failed,
                description: 'The browser returned no callback URL.',
              ),
            )
          : Ok(UserAgentCallback(uri: uri));
    });
  }

  @override
  Future<void> discardCallback(Uri cleanUri) async {}
}
