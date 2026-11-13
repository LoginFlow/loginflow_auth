import 'package:flutter_test/flutter_test.dart';
import 'package:loginflow_auth/src/core/crypto/pkce_pair.dart';
import 'package:loginflow_auth/src/core/flow/authorization_attempt.dart';
import 'package:loginflow_auth/src/core/protocol/challenge/authorization_intent.dart';
import 'package:loginflow_auth/src/core/state/challenge_purpose.dart';

/// `intent` on an [AuthorizationAttempt]: carried to the opening's
/// authorization parameters and part of the value's equality. An attempt is
/// internal flow state, never persisted, so it has no `toJson`/`fromJson`.
void main() {
  const pkce = PkcePair(
    codeVerifier: 'dBjftJeZ4CVP-mB92K27uhbUJU1p1r_wW1gFWFOEjXk',
    codeChallenge: 'E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM',
  );
  final reset = AuthorizationAttempt(
    purpose: ChallengePurpose.passwordReset,
    pkce: pkce,
    nonce: 'nonce-1',
    state: 'state-1',
    loginHint: 'luz@example.com',
    intent: AuthorizationIntent.passwordReset.wireName,
  );
  final withoutIntent = AuthorizationAttempt(
    purpose: reset.purpose,
    pkce: reset.pkce,
    nonce: reset.nonce,
    state: reset.state,
    loginHint: reset.loginHint,
  );

  // TEST_CHARTER
  // Requirement: the attempt's `intent` is what the opening request sends.
  // Oracle: the authorization parameters `toParameters` builds.
  // Risk edge: `intent` held by the attempt but never put on the wire.
  // Layer: the flow model.
  // Counterfactual: leaving `intent` out of `toParameters`.
  test('toParameters carries intent', () {
    final parameters = reset.toParameters(
      scope: 'openid',
      redirectUri: null,
      uiLocales: const <String>[],
    );

    expect(parameters.intent, 'password_reset');
  });

  // TEST_CHARTER
  // Requirement: `intent` survives `copyWith`, `withDeviceSignIn` and
  // `withEmailCodeResendAvailableAt`, and two attempts differing only by it
  // are different values.
  // Oracle: equality and hash.
  // Risk edge: `intent` lost on a state transition of the attempt.
  // Layer: the flow model.
  // Counterfactual: removing `intent` from any of those members.
  test('intent survives every copy and takes part in == and hashCode', () {
    expect(reset.copyWith(isAuthorizationSent: true).intent, 'password_reset');
    expect(reset.withDeviceSignIn(null), reset);
    expect(reset.withEmailCodeResendAvailableAt(null), reset);
    expect(withoutIntent.copyWith(intent: 'password_reset'), reset);
    expect(
      withoutIntent.copyWith(intent: 'password_reset').hashCode,
      reset.hashCode,
    );
    expect(withoutIntent, isNot(reset));
    expect(withoutIntent.hashCode, isNot(reset.hashCode));
  });
}
