import 'package:flutter/services.dart';
import 'package:loginflow_auth/loginflow_auth_core.dart';

/// [GoogleIdTokenSource] over Credential Manager ("Sign in with Google"
/// bottom sheet) on Android and GIDSignIn on iOS.
///
/// The token is requested with `prompt.nonce`, the value the server bound
/// to this sign-in attempt (G-ANDROID-SIWG, G-IOS-BACKEND), and the
/// company's Google web client as `serverClientId`. That client ID is
/// `prompt.clientId` unless [serverClientId] overrides it: both carry the
/// same value LoginFlow publishes ahead of time as
/// `ClientLoginOptions.googleServerClientId` (`GET /oauth2/login-options`,
/// `doc/server-contract.md` §4) — `prompt.clientId` is simply that same
/// `oauth_provider_configs` row, re-resolved per attempt. [serverClientId]
/// exists only for the rare case an app needs to force a different one
/// (e.g. local testing against a server with Google not yet configured);
/// leaving it unset is correct for every real deployment.
final class NativeGoogleIdTokenSource implements GoogleIdTokenSource {
  const NativeGoogleIdTokenSource({this.iosClientId, this.serverClientId});

  static const MethodChannel channel = MethodChannel(
    'dev.loginflow.auth.google/native',
  );

  /// The iOS OAuth client ID; when null the `GIDClientID` Info.plist key is
  /// used. Android needs none.
  final String? iosClientId;

  /// Explicit override of the Google web client ID; `prompt.clientId` is
  /// used when this is `null` (the default, and the correct choice for
  /// every real deployment — see the class doc).
  final String? serverClientId;

  @override
  Future<Result<String, LoginFlowError>> obtainIdToken(
    UpstreamPrompt prompt,
  ) async {
    try {
      final token = await channel.invokeMethod<String>('getIdToken', {
        'serverClientId': serverClientId ?? prompt.clientId,
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
