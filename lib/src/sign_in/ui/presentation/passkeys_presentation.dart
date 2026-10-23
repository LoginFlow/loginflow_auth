import 'package:flutter/material.dart';
import 'package:loginflow_auth/src/core/protocol/passkeys/passkey_credential.dart';
import 'package:loginflow_auth/src/sign_in/l10n/login_flow_strings.dart';
import 'package:loginflow_auth/src/sign_in/model/field_error.dart';
import 'package:loginflow_auth/src/sign_in/model/passkeys_feedback.dart';
import 'package:loginflow_auth/src/sign_in/ui/sign_in_keys.dart';

/// Text of the passkey manager's banner; `null` hides it.
extension PasskeysFeedbackPresentation on PasskeysFeedback {
  String? toMessage(LoginFlowStrings strings) => switch (this) {
    PasskeysFeedback.none => null,
    PasskeysFeedback.network => strings.feedbackNetwork,
    PasskeysFeedback.sessionEnded => strings.feedbackSessionRevoked,
    PasskeysFeedback.rateLimited => strings.feedbackRateLimited,
    PasskeysFeedback.notFound => strings.feedbackPasskeyNotFound,
    PasskeysFeedback.passkeysUnavailable => strings.feedbackPasskeysUnavailable,
    PasskeysFeedback.reauthenticationRequired =>
      strings.feedbackReauthenticationRequired,
    PasskeysFeedback.unexpected => strings.feedbackUnexpected,
    PasskeysFeedback.passkeyNotConfigured =>
      strings.feedbackPasskeyNotConfigured,
    PasskeysFeedback.passkeyNotSupported => strings.feedbackPasskeyNotSupported,
    PasskeysFeedback.passkeyNoCredentials =>
      strings.feedbackPasskeyNoCredentials,
    PasskeysFeedback.passkeySecurityError =>
      strings.feedbackPasskeySecurityError,
    PasskeysFeedback.passkeyDomainNotAssociated =>
      strings.feedbackPasskeyDomainNotAssociated,
    PasskeysFeedback.passkeyAlreadyRegistered =>
      strings.feedbackPasskeyAlreadyRegistered,
    PasskeysFeedback.passkeyTimeout => strings.feedbackPasskeyTimeout,
    PasskeysFeedback.passkeyInvalidResponse =>
      strings.feedbackPasskeyInvalidResponse,
    PasskeysFeedback.passkeyFailed => strings.feedbackPasskeyFailed,
  };
}

/// How one enrolled passkey is named and described.
extension PasskeyCredentialPresentation on PasskeyCredential {
  /// The user's name for it, or a generic one when never named.
  String toDisplayName(LoginFlowStrings strings) =>
      name ?? strings.passkeyUnnamed;

  /// When it was added and, once used, when it was last used — dates in
  /// the user's time zone, formatted by the ambient [MaterialLocalizations].
  String toDetails(LoginFlowStrings strings, MaterialLocalizations dates) {
    final added = strings.passkeyAddedOn(
      dates.formatMediumDate(createdAt.toLocal()),
    );
    final lastUsed = lastUsedAt;
    if (lastUsed == null) {
      return added;
    }
    return '$added · '
        '${strings.passkeyLastUsedOn(dates.formatMediumDate(lastUsed.toLocal()))}';
  }

  ValueKey<String> toRenameKey() =>
      ValueKey<String>('${SignInKeys.passkeyRenamePrefix}.$id');

  ValueKey<String> toDeleteKey() =>
      ValueKey<String>('${SignInKeys.passkeyDeletePrefix}.$id');
}

/// Field error text of a passkey name; `null` means it is fine.
extension PasskeyNameErrorPresentation on FieldError {
  String? toPasskeyNameMessage(LoginFlowStrings strings) => switch (this) {
    FieldError.none => null,
    FieldError.required ||
    FieldError.invalidEmail ||
    FieldError.incompleteAccessCode => strings.passkeyNameRequired,
  };
}
