import 'package:flutter/services.dart';
import 'package:loginflow_auth/loginflow_auth_core.dart';

/// [GoogleIdTokenSource] over Credential Manager ("Sign in with Google"
/// bottom sheet) on Android and GIDSignIn on iOS.
///
/// The token is requested for `prompt.clientId` (the company's Google web
/// client, LoginFlow verifies it as `aud`) with `prompt.nonce`, the value
/// the server bound to this sign-in attempt (G-ANDROID-SIWG,
/// G-IOS-BACKEND).
final class NativeGoogleIdTokenSource implements GoogleIdTokenSource {
  const NativeGoogleIdTokenSource({this.iosClientId});

  static const MethodChannel channel = MethodChannel(
    'dev.loginflow.auth.google/native',
  );

  /// The iOS OAuth client ID; when null the `GIDClientID` Info.plist key is
  /// used. Android needs none.
  final String? iosClientId;

  @override
  Future<Result<String, LoginFlowError>> obtainIdToken(
    UpstreamPrompt prompt,
  ) async {
    try {
      final token = await channel.invokeMethod<String>('getIdToken', {
        'serverClientId': prompt.clientId,
        'nonce': prompt.nonce,
        'iosClientId': ?iosClientId,
      });
      return token == null || token.isEmpty
          ? Err(_failed(UpstreamFailureReason.failed))
          : Ok(token);
    } on PlatformException catch (error) {
      return Err(
        _failed(switch (error.code) {
          'CANCELLED' => UpstreamFailureReason.cancelled,
          'NO_CREDENTIAL' => UpstreamFailureReason.noCredential,
          'UNAVAILABLE' ||
          'MISCONFIGURED' => UpstreamFailureReason.notConfigured,
          _ => UpstreamFailureReason.failed,
        }),
      );
    } on MissingPluginException {
      return Err(_failed(UpstreamFailureReason.notConfigured));
    }
  }

  UpstreamFailed _failed(UpstreamFailureReason reason) =>
      UpstreamFailed(provider: UpstreamProvider.google, reason: reason);
}
