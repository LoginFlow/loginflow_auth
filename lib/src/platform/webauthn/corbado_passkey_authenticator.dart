import 'dart:async';

import 'package:flutter/services.dart';
import 'package:logger_rs/logger_rs.dart';
import 'package:loginflow_auth/src/core/error/login_flow_error.dart';
import 'package:loginflow_auth/src/core/error/passkey_failure_reason.dart';
import 'package:loginflow_auth/src/core/webauthn/passkey_authenticator.dart';
import 'package:passkeys/authenticator.dart' as corbado;
import 'package:passkeys/types.dart' as corbado;
import 'package:result_controller/result_controller.dart';

/// [PasskeyAuthenticator] backed by the `passkeys` pub package (Corbado):
/// Android Credential Manager, iOS/macOS AuthenticationServices and the
/// browser's WebAuthn API, through one federated Flutter plugin.
///
/// This server's `webauthn-rs` wraps its options in a `publicKey` member
/// (and, for authentication, an optional `mediation`) — the raw
/// `navigator.credentials.{create,get}()` call shape
/// (webauthn-rs-proto `CreationChallengeResponse`/`RequestChallengeResponse`,
/// `#[serde(rename_all = "camelCase")]`). This adapter unwraps that before
/// handing the options to Corbado's typed request, and the raw JSON Corbado
/// returns (`RegisterResponseType.toJson()`/`AuthenticateResponseType.toJson()`)
/// is already the nested `{id, rawId, type, response: {...}}` shape
/// `webauthn-rs`'s `PublicKeyCredential` deserializer expects — no reshaping
/// needed on the way back either.
///
/// Every ceremony is modal: the server's `mediation: "conditional"` (sent
/// for a discoverable request) is never forwarded, because a conditional
/// request only resolves from a focused autofill field, and without one it
/// waits forever on iOS and the web. Every ceremony is also bounded by
/// [ceremonyTimeout], and every failure — whatever the plugin or the JSON
/// throws — comes back as `PasskeyFailed` with a [PasskeyFailureReason],
/// never as an exception.
class CorbadoPasskeyAuthenticator implements PasskeyAuthenticator {
  CorbadoPasskeyAuthenticator({
    corbado.PasskeyAuthenticator? authenticator,
    this.ceremonyTimeout = defaultCeremonyTimeout,
  }) : _authenticator = authenticator ?? corbado.PasskeyAuthenticator();

  /// WebAuthn's recommended upper bound for a ceremony with user
  /// verification (WebAuthn L3 §5.4.1, `timeout`).
  static const Duration defaultCeremonyTimeout = Duration(seconds: 120);

  /// Prefix of Android Credential Manager's WebAuthn `DOMException` types,
  /// which the plugin forwards as
  /// `android-unhandled: <exception type>/androidx.credentials.TYPE_<NAME>`.
  static const String _androidDomErrorPrefix = 'androidx.credentials.TYPE_';

  /// How long a ceremony may run before it fails as
  /// `PasskeyFailed(reason: timeout)`.
  final Duration ceremonyTimeout;

  final corbado.PasskeyAuthenticator _authenticator;

  @override
  Future<Result<Map<String, Object?>, LoginFlowError>> getAssertion({
    required Map<String, Object?> options,
  }) => _runCeremony(options, (publicKey) async {
    final request = corbado.AuthenticateRequestType.fromJson(publicKey);
    final response = await _authenticator.authenticate(request);
    return response.toJson();
  });

  @override
  Future<Result<Map<String, Object?>, LoginFlowError>> createCredential({
    required Map<String, Object?> options,
  }) => _runCeremony(options, (publicKey) async {
    final request = corbado.RegisterRequestType.fromJson(publicKey);
    final response = await _authenticator.register(request);
    return response.toJson();
  });

  Future<Result<Map<String, Object?>, LoginFlowError>> _runCeremony(
    Map<String, Object?> options,
    Future<Map<String, Object?>> Function(Map<String, dynamic> publicKey)
    ceremony,
  ) async {
    final publicKey = options['publicKey'];
    if (publicKey is! Map<String, Object?>) {
      return _failed(
        const PasskeyFailed(
          reason: PasskeyFailureReason.invalidResponse,
          description: 'The options have no "publicKey" object.',
        ),
      );
    }
    try {
      final credential = await ceremony(Map<String, dynamic>.from(publicKey))
          .timeout(ceremonyTimeout);
      return Ok(credential);
    } on TimeoutException {
      await _cancelStuckCeremony();
      return _failed(
        PasskeyFailed(
          reason: PasskeyFailureReason.timeout,
          description: 'No result within ${ceremonyTimeout.inSeconds}s.',
        ),
      );
    } on corbado.AuthenticatorException catch (error) {
      return _failed(_fromAuthenticatorException(error));
    } on PlatformException catch (error) {
      return _failed(
        PasskeyFailed(
          reason: _reasonForCode(error.code),
          code: error.code,
          description: error.message,
        ),
      );
    } on FormatException catch (error) {
      return _failed(
        PasskeyFailed(
          reason: PasskeyFailureReason.invalidResponse,
          description: error.message,
        ),
      );
    } on TypeError catch (error) {
      return _failed(
        PasskeyFailed(
          reason: PasskeyFailureReason.invalidResponse,
          description: '$error',
        ),
      );
    } on Object catch (error) {
      return _failed(
        PasskeyFailed(
          reason: PasskeyFailureReason.unknown,
          description: '$error',
        ),
      );
    }
  }

  /// Dismisses the platform sheet a timed-out ceremony left open, so the
  /// next attempt does not queue behind it. Best effort: a failure here
  /// changes nothing for the caller, the ceremony already failed.
  Future<void> _cancelStuckCeremony() async {
    try {
      await _authenticator.cancelCurrentAuthenticatorOperation();
    } on Object catch (error) {
      Log.w('Cancelling a timed-out passkey ceremony failed: $error');
    }
  }

  Result<Map<String, Object?>, LoginFlowError> _failed(PasskeyFailed error) {
    Log.w('${error.message}: ${error.description ?? '-'}');
    return Err(error);
  }

  PasskeyFailed _fromAuthenticatorException(
    corbado.AuthenticatorException error,
  ) {
    final reason = switch (error) {
      corbado.PasskeyAuthCancelledException() =>
        PasskeyFailureReason.userCancelled,
      corbado.NoCredentialsAvailableException() =>
        PasskeyFailureReason.noCredentialsAvailable,
      corbado.DomainNotAssociatedException() =>
        PasskeyFailureReason.domainNotAssociated,
      corbado.ExcludeCredentialsCanNotBeRegisteredException() =>
        PasskeyFailureReason.alreadyRegistered,
      corbado.TimeoutException() => PasskeyFailureReason.timeout,
      corbado.DeviceNotSupportedException() ||
      corbado.PasskeyUnsupportedException() ||
      corbado.MissingGoogleSignInException() ||
      corbado.SyncAccountNotAvailableException() ||
      corbado.NoCreateOptionException() ||
      corbado.RestoreCredentialUnsupportedException() =>
        PasskeyFailureReason.notSupported,
      corbado.MalformedBase64Url() => PasskeyFailureReason.invalidResponse,
      corbado.UnhandledAuthenticatorException(:final code) => _reasonForCode(
        code,
      ),
    };
    return switch (error) {
      corbado.UnhandledAuthenticatorException(:final code, :final message) =>
        PasskeyFailed(reason: reason, code: code, description: message),
      _ => PasskeyFailed(reason: reason, description: '$error'),
    };
  }

  /// A platform error code: a WebAuthn `DOMException` name (the web, and
  /// Android's DOM error types), or a code of the plugin's native side
  /// that Corbado itself does not translate.
  PasskeyFailureReason _reasonForCode(String code) => switch (_domErrorName(
    code,
  )) {
    'cancelled' ||
    'suppressed' ||
    'NotAllowedError' ||
    'AbortError' => PasskeyFailureReason.userCancelled,
    'no-credentials-available' ||
    'android-no-credential' => PasskeyFailureReason.noCredentialsAvailable,
    'SecurityError' => PasskeyFailureReason.securityError,
    'domain-not-associated' => PasskeyFailureReason.domainNotAssociated,
    'InvalidStateError' ||
    'exclude-credentials-match' => PasskeyFailureReason.alreadyRegistered,
    'NotSupportedError' ||
    'deviceNotSupported' ||
    'android-passkey-unsupported' => PasskeyFailureReason.notSupported,
    'TimeoutError' ||
    'android-timeout' ||
    'ios-security-key-timeout' => PasskeyFailureReason.timeout,
    'EncodingError' ||
    'invalidResponse' ||
    'parse-error' ||
    'decodingChallenge' ||
    'unexpectedAuthorizationResponse' => PasskeyFailureReason.invalidResponse,
    _ => PasskeyFailureReason.unknown,
  };

  /// The WebAuthn `DOMException` name inside an Android Credential Manager
  /// code (`.../androidx.credentials.TYPE_SECURITY_ERROR` ->
  /// `SecurityError`); any other code unchanged.
  String _domErrorName(String code) {
    final start = code.lastIndexOf(_androidDomErrorPrefix);
    if (start < 0) {
      return code;
    }
    return switch (code.substring(start + _androidDomErrorPrefix.length)) {
      'NOT_ALLOWED_ERROR' => 'NotAllowedError',
      'ABORT_ERROR' => 'AbortError',
      'SECURITY_ERROR' => 'SecurityError',
      'INVALID_STATE_ERROR' => 'InvalidStateError',
      'NOT_SUPPORTED_ERROR' => 'NotSupportedError',
      'TIMEOUT_ERROR' => 'TimeoutError',
      'ENCODING_ERROR' => 'EncodingError',
      _ => code,
    };
  }
}
