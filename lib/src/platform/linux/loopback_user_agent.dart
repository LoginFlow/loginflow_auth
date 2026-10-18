import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:logger_rs/logger_rs.dart';
import 'package:loginflow_auth/src/core/browser/external_user_agent.dart';
import 'package:loginflow_auth/src/core/error/browser_failure_reason.dart';
import 'package:loginflow_auth/src/core/error/login_flow_error.dart';
import 'package:result_controller/result_controller.dart';
import 'package:url_launcher/url_launcher.dart';

/// [ExternalUserAgent] for desktop platforms without an authentication
/// session API (Linux): the user's default browser (`xdg-open`) and an
/// RFC 8252 §7.3 loopback redirect — the app listens on the redirect URI's
/// `127.0.0.1`/`[::1]` port for exactly one matching callback. Never a
/// WebView (RFC 8252 §8.12).
///
/// LoginFlow compares redirect URIs exactly (port included), so the client
/// registers a FIXED port (`http://127.0.0.1:<port>/<path>`), not the
/// ephemeral port RFC 8252 §7.3 allows.
final class LoopbackUserAgent implements ExternalUserAgent {
  const LoopbackUserAgent({
    this.launch = LoopbackUserAgent.openInSystemBrowser,
    this.timeout = const Duration(minutes: 10),
  });

  /// Opens a URL in the system browser; `false` when none could be opened.
  final Future<bool> Function(Uri url) launch;

  /// How long the user may stay in the browser; matches the lifetime of a
  /// pending authorization (`LoginFlowAuth.pendingLifetime`).
  final Duration timeout;

  /// Shown in the browser tab once the callback is received.
  static const String _completionPage =
      '<!doctype html><meta charset="utf-8"><title>LoginFlow</title>'
      '<p>Sign-in finished. You can close this tab.</p>';

  static Future<bool> openInSystemBrowser(Uri url) async {
    try {
      return await launchUrl(url, mode: LaunchMode.externalApplication);
    } on PlatformException catch (error) {
      Log.w('Opening the system browser failed: ${error.message}');
      return false;
    }
  }

  @override
  Future<Result<UserAgentOutcome, LoginFlowError>> open(
    Uri url, {
    required Uri callbackUri,
    required String expectedState,
  }) async {
    final address = callbackUri.loopbackAddress;
    if (address == null) {
      return Err(
        const BrowserFailed(
          reason: BrowserFailureReason.unavailable,
          description:
              'A desktop browser step needs a loopback redirect URI '
              '(http://127.0.0.1:<port>/<path>, RFC 8252 §7.3).',
        ),
      );
    }
    final HttpServer server;
    try {
      server = await HttpServer.bind(address, callbackUri.port);
    } on SocketException catch (error) {
      return Err(
        BrowserFailed(
          reason: BrowserFailureReason.failed,
          description: 'Cannot listen on ${callbackUri.port}: ${error.message}',
        ),
      );
    }
    final callback = _awaitCallback(server, callbackUri, expectedState);
    try {
      if (!await launch(url)) {
        return Err(
          const BrowserFailed(
            reason: BrowserFailureReason.unavailable,
            description: 'No system browser could be opened.',
          ),
        );
      }
      final received = await callback.timeout(timeout);
      return received == null
          ? Err(const BrowserFailed(reason: BrowserFailureReason.cancelled))
          : Ok(UserAgentCallback(uri: received));
    } on TimeoutException {
      return Err(
        const BrowserFailed(
          reason: BrowserFailureReason.cancelled,
          description: 'The browser did not return in time.',
        ),
      );
    } finally {
      await server.close(force: true);
    }
  }

  @override
  Future<void> discardCallback(Uri cleanUri) async {}

  /// The first request to the redirect path that carries [expectedState]:
  /// any other navigation is answered `404` and ignored, so a forged one
  /// cannot abort the sign-in (`doc/decisions.md` D17). `null` when the
  /// server closes first.
  Future<Uri?> _awaitCallback(
    HttpServer server,
    Uri callbackUri,
    String expectedState,
  ) async {
    await for (final request in server) {
      final isExpected =
          request.uri.path == callbackUri.path &&
          request.uri.queryParameters['state'] == expectedState;
      request.response
        ..statusCode = isExpected ? HttpStatus.ok : HttpStatus.notFound
        ..headers.contentType = ContentType.html
        ..write(isExpected ? _completionPage : '');
      await request.response.close();
      if (isExpected) {
        return callbackUri.replace(query: request.uri.query);
      }
    }
    return null;
  }
}

extension on Uri {
  /// The interface an RFC 8252 §7.3 loopback redirect URI listens on, or
  /// `null` when this is not one (`http`, an IP literal, an explicit port).
  InternetAddress? get loopbackAddress {
    if (scheme != 'http' || !hasPort || port == 0) {
      return null;
    }
    return switch (host) {
      '127.0.0.1' => InternetAddress.loopbackIPv4,
      '::1' => InternetAddress.loopbackIPv6,
      _ => null,
    };
  }
}
