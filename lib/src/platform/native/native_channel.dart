import 'package:flutter/services.dart';
import 'package:loginflow_auth/src/core/error/browser_failure_reason.dart';
import 'package:loginflow_auth/src/core/error/login_flow_error.dart';
import 'package:result_controller/result_controller.dart';

/// The method channel shared by the Android and Apple implementations.
abstract final class NativeChannel {
  static const MethodChannel channel = MethodChannel(
    'dev.loginflow.auth/native',
  );

  static const String privateRead = 'privateStore.read';
  static const String privateWrite = 'privateStore.write';
  static const String privateDelete = 'privateStore.delete';
  static const String ssoRead = 'sso.read';
  static const String ssoWrite = 'sso.write';
  static const String ssoDelete = 'sso.delete';
  static const String browserAuthenticate = 'browser.authenticate';
  static const String dpopEnsureKey = 'dpop.ensureKey';
  static const String dpopSign = 'dpop.sign';

  static const String cancelledCode = 'CANCELLED';
  static const String unavailableCode = 'UNAVAILABLE';

  /// Invokes a storage method; platform exceptions become [StorageFailure].
  static Future<Result<String?, LoginFlowError>> invokeStorage(
    String method,
    Map<String, Object?> arguments,
  ) async {
    try {
      return Ok(await channel.invokeMethod<String>(method, arguments));
    } on PlatformException catch (error) {
      return Err(
        StorageFailure(description: '${error.code}: ${error.message}'),
      );
    } on MissingPluginException {
      return Err(
        const StorageFailure(
          description: 'No native storage on this platform.',
        ),
      );
    }
  }

  /// Invokes the browser method; platform exceptions become [BrowserFailed].
  static Future<Result<String?, LoginFlowError>> invokeBrowser(
    Map<String, Object?> arguments,
  ) async {
    try {
      return Ok(
        await channel.invokeMethod<String>(browserAuthenticate, arguments),
      );
    } on PlatformException catch (error) {
      final reason = switch (error.code) {
        cancelledCode => BrowserFailureReason.cancelled,
        unavailableCode => BrowserFailureReason.unavailable,
        _ => BrowserFailureReason.failed,
      };
      return Err(BrowserFailed(reason: reason, description: error.message));
    } on MissingPluginException {
      return Err(const BrowserFailed(reason: BrowserFailureReason.unavailable));
    }
  }
}
