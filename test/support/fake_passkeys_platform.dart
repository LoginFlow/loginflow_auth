import 'dart:async';

import 'package:passkeys/types.dart';
import 'package:passkeys_platform_interface/passkeys_platform_interface.dart';

/// Plays the native half of the `passkeys` plugin (Credential Manager,
/// AuthenticationServices, the browser's WebAuthn bridge) underneath the
/// REAL Corbado `PasskeyAuthenticator`, so the plugin's own
/// `PlatformException` -> `AuthenticatorException` translation runs exactly
/// as it does on a device.
class FakePasskeysPlatform extends PasskeysPlatform {
  /// Thrown by every `register`/`authenticate` call while set.
  Object? failure;

  /// When `true`, `register`/`authenticate` never complete — what an iOS or
  /// web conditional (autofill) request does when no text field ever
  /// triggers it.
  bool isHanging = false;

  final List<AuthenticateRequestType> authenticateRequests =
      <AuthenticateRequestType>[];
  final List<RegisterRequestType> registerRequests = <RegisterRequestType>[];
  int cancelCount = 0;

  @override
  Future<AuthenticateResponseType> authenticate(
    AuthenticateRequestType request,
  ) async {
    authenticateRequests.add(request);
    await _ceremony();
    return const AuthenticateResponseType(
      id: 'Y3JlZGVudGlhbA',
      rawId: 'Y3JlZGVudGlhbA',
      clientDataJSON: 'e30',
      authenticatorData: 'AAAA',
      signature: 'AAAA',
      userHandle: 'dXNlcg',
    );
  }

  @override
  Future<RegisterResponseType> register(RegisterRequestType request) async {
    registerRequests.add(request);
    await _ceremony();
    return const RegisterResponseType(
      id: 'Y3JlZGVudGlhbA',
      rawId: 'Y3JlZGVudGlhbA',
      clientDataJSON: 'e30',
      attestationObject: 'AAAA',
      transports: <String?>['internal'],
    );
  }

  @override
  Future<void> cancelCurrentAuthenticatorOperation() async {
    cancelCount++;
  }

  @override
  Future<AvailabilityType> getAvailability() =>
      throw UnimplementedError('Not used by the library.');

  Future<void> _ceremony() {
    if (isHanging) {
      return Completer<void>().future;
    }
    final failure = this.failure;
    if (failure != null) {
      throw failure;
    }
    return Future<void>.value();
  }
}
