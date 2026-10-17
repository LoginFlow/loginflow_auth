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
class CorbadoPasskeyAuthenticator implements PasskeyAuthenticator {
  CorbadoPasskeyAuthenticator({corbado.PasskeyAuthenticator? authenticator})
    : _authenticator = authenticator ?? corbado.PasskeyAuthenticator();

  final corbado.PasskeyAuthenticator _authenticator;

  @override
  Future<Result<Map<String, Object?>, LoginFlowError>> getAssertion({
    required Map<String, Object?> options,
  }) async {
    final publicKey = options['publicKey'];
    if (publicKey is! Map<String, Object?>) {
      return Err(
        const PasskeyFailed(reason: PasskeyFailureReason.invalidResponse),
      );
    }
    try {
      final request = corbado.AuthenticateRequestType.fromJson(
        Map<String, dynamic>.from(publicKey),
        mediation: options['mediation'] == 'conditional'
            ? corbado.MediationType.Conditional
            : corbado.MediationType.Optional,
      );
      final response = await _authenticator.authenticate(request);
      return Ok(response.toJson());
    } on corbado.AuthenticatorException catch (error) {
      return Err(_mapException(error));
    }
  }

  @override
  Future<Result<Map<String, Object?>, LoginFlowError>> createCredential({
    required Map<String, Object?> options,
  }) async {
    final publicKey = options['publicKey'];
    if (publicKey is! Map<String, Object?>) {
      return Err(
        const PasskeyFailed(reason: PasskeyFailureReason.invalidResponse),
      );
    }
    try {
      final request = corbado.RegisterRequestType.fromJson(
        Map<String, dynamic>.from(publicKey),
      );
      final response = await _authenticator.register(request);
      return Ok(response.toJson());
    } on corbado.AuthenticatorException catch (error) {
      return Err(_mapException(error));
    }
  }

  LoginFlowError _mapException(corbado.AuthenticatorException error) {
    switch (error) {
      case corbado.PasskeyAuthCancelledException():
        return const PasskeyFailed(reason: PasskeyFailureReason.userCancelled);
      case corbado.NoCredentialsAvailableException():
        return const PasskeyFailed(
          reason: PasskeyFailureReason.noCredentialsAvailable,
        );
      case corbado.DeviceNotSupportedException():
      case corbado.PasskeyUnsupportedException():
      case corbado.MissingGoogleSignInException():
      case corbado.SyncAccountNotAvailableException():
      case corbado.NoCreateOptionException():
      case corbado.DomainNotAssociatedException():
      case corbado.RestoreCredentialUnsupportedException():
        return const PasskeyFailed(reason: PasskeyFailureReason.notSupported);
      case corbado.ExcludeCredentialsCanNotBeRegisteredException():
      case corbado.TimeoutException():
      case corbado.MalformedBase64Url():
      case corbado.UnhandledAuthenticatorException():
        Log.w('Passkey ceremony failed: $error');
        return const PasskeyFailed(reason: PasskeyFailureReason.invalidResponse);
    }
  }
}
