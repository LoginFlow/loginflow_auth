import 'package:flutter_test/flutter_test.dart';
import 'package:loginflow_auth/src/core/protocol/challenge/authorization_intent.dart';
import 'package:loginflow_auth/src/core/protocol/challenge/challenge_authorization_parameters.dart';

/// `intent` on the opening request's authorization parameters
/// (`doc/server-contract.md` §5.4): on the wire only when set, through
/// `toJson`/`fromJson`, and part of the value's equality.
void main() {
  final reset = ChallengeAuthorizationParameters(
    scope: 'openid offline_access',
    codeChallenge: 'E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM',
    nonce: 'nonce-1',
    intent: AuthorizationIntent.passwordReset.wireName,
  );
  final signIn = ChallengeAuthorizationParameters(
    scope: reset.scope,
    codeChallenge: reset.codeChallenge,
    nonce: reset.nonce,
  );

  // TEST_CHARTER
  // Requirement: the reset's `intent` reaches the server as
  // `intent=password_reset`, and a sign-in sends no `intent` at all.
  // Oracle: the form fields.
  // Risk edge: an empty or `null` `intent` field on every opening.
  // Layer: the wire model.
  // Counterfactual: dropping `intent` from `toFormFields`, or writing it
  // unconditionally.
  test('intent is a form field only when set', () {
    expect(reset.toFormFields()['intent'], 'password_reset');
    expect(signIn.toFormFields(), isNot(contains('intent')));
  });

  // TEST_CHARTER
  // Requirement: `intent` survives `toJson`/`fromJson` and `copyWith`, and
  // two parameters differing only by it are different values.
  // Oracle: equality and hash of the round-tripped values.
  // Risk edge: a field left out of `fromJson`, `==` or `hashCode`.
  // Layer: the wire model.
  // Counterfactual: removing `intent` from any of those members.
  test('intent round-trips and takes part in == and hashCode', () {
    final again = ChallengeAuthorizationParameters.fromJson(reset.toJson());

    expect(reset.toJson()['intent'], 'password_reset');
    expect(signIn.toJson(), isNot(contains('intent')));
    expect(again, reset);
    expect(again.hashCode, reset.hashCode);
    expect(signIn.copyWith(intent: 'password_reset'), reset);
    expect(signIn, isNot(reset));
    expect(signIn.hashCode, isNot(reset.hashCode));
  });
}
