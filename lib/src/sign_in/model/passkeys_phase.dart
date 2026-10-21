import 'package:loginflow_auth/src/core/json/list_equality.dart';
import 'package:loginflow_auth/src/core/protocol/passkeys/passkey_credential.dart';

/// Which screen of the passkey manager is showing.
///
/// Phases are transient UI state rebuilt from the authentication state and
/// the account passkey API; they are never serialized, so they have no
/// `toJson`/`fromJson`.
sealed class PasskeysPhase {
  const PasskeysPhase();
}

/// `LoginFlowSignInSetup.install` was not called.
final class PasskeysNotConfigured extends PasskeysPhase {
  const PasskeysNotConfigured();

  @override
  bool operator ==(Object other) => other is PasskeysNotConfigured;

  @override
  int get hashCode => (PasskeysNotConfigured).hashCode;
}

/// Nobody is signed in: there is no account to manage.
final class PasskeysSignedOut extends PasskeysPhase {
  const PasskeysSignedOut();

  @override
  bool operator ==(Object other) => other is PasskeysSignedOut;

  @override
  int get hashCode => (PasskeysSignedOut).hashCode;
}

/// Reading the signed-in user's passkeys (`GET /v1/user/passkeys`).
final class PasskeysLoading extends PasskeysPhase {
  const PasskeysLoading();

  @override
  bool operator ==(Object other) => other is PasskeysLoading;

  @override
  int get hashCode => (PasskeysLoading).hashCode;
}

/// The passkeys could not be read; the feedback says why.
final class PasskeysLoadFailed extends PasskeysPhase {
  const PasskeysLoadFailed();

  @override
  bool operator ==(Object other) => other is PasskeysLoadFailed;

  @override
  int get hashCode => (PasskeysLoadFailed).hashCode;
}

/// The signed-in user's passkeys, in the server's order.
final class PasskeysListed extends PasskeysPhase {
  const PasskeysListed({required this.passkeys});

  final List<PasskeyCredential> passkeys;

  PasskeysListed copyWith({List<PasskeyCredential>? passkeys}) =>
      PasskeysListed(passkeys: passkeys ?? this.passkeys);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PasskeysListed && passkeys.hasSameValues(other.passkeys);

  @override
  int get hashCode => passkeys.valuesHash;
}

/// Adding a passkey needs a recent sign-in (RFC 9470): the user signs in
/// again through the sign-in steps, and the enrollment is retried once.
/// [passkeys] is the list shown again when the user cancels.
final class PasskeysReauthenticating extends PasskeysPhase {
  const PasskeysReauthenticating({required this.passkeys});

  final List<PasskeyCredential> passkeys;

  PasskeysReauthenticating copyWith({List<PasskeyCredential>? passkeys}) =>
      PasskeysReauthenticating(passkeys: passkeys ?? this.passkeys);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PasskeysReauthenticating &&
          passkeys.hasSameValues(other.passkeys);

  @override
  int get hashCode =>
      Object.hash(PasskeysReauthenticating, passkeys.valuesHash);
}
