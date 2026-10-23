/// Every text of the built-in sign-in UI.
abstract interface class LoginFlowStrings {
  /// Title of the entry screen.
  /// English: "Sign in".
  String get signInTitle;

  /// English: "Choose how you want to continue".
  String get signInSubtitle;

  /// English: "Continue with password".
  String get continueWithPassword;

  /// English: "Email me a code".
  String get continueWithEmailCode;

  /// English: "Continue with Google".
  String get continueWithGoogle;

  /// English: "Continue with Microsoft".
  String get continueWithMicrosoft;

  /// English: "Continue with Apple".
  String get continueWithApple;

  /// English: "Continue with Facebook".
  String get continueWithFacebook;

  /// English: "Continue with a passkey".
  String get continueWithPasskey;

  /// English: "Temporary access pass".
  String get temporaryAccessPassTitle;

  /// English: "Enter the temporary access pass your administrator gave you."
  String get temporaryAccessPassInstructions;

  /// English: "Use a temporary access pass".
  String get useTemporaryAccessPass;

  /// English: "Email".
  String get emailLabel;

  /// English: "Password".
  String get passwordLabel;

  /// English: "Show password".
  String get showPassword;

  /// English: "Hide password".
  String get hidePassword;

  /// English: "Sign in".
  String get signInButton;

  /// English: "Forgot your password?"
  String get forgotPassword;

  /// English: "Send code".
  String get sendCodeButton;

  /// English: "Code".
  String get codeLabel;

  /// Confirms the code was sent to this email.
  /// English: "We sent a code to {email}".
  String codeSentTo(String email);

  /// English: "Verify".
  String get verifyButton;

  /// English: "Resend code".
  String get resendCode;

  /// Countdown before the resend button is enabled again.
  /// English: "Resend code in {seconds}s".
  String resendIn(int seconds);

  /// English: "Email me a sign-in link instead".
  String get sendMagicLink;

  /// English: "Two-step verification".
  String get twoStepTitle;

  /// English: "Enter the 6-digit code from your authenticator app."
  String get authenticatorInstructions;

  /// English: "Enter one of your recovery codes."
  String get recoveryInstructions;

  /// English: "Use a recovery code".
  String get useRecoveryCode;

  /// English: "Use your authenticator app".
  String get useAuthenticatorCode;

  /// English: "Back".
  String get back;

  /// English: "Create an account".
  String get createAccount;

  /// English: "Continue in your browser…".
  String get continueInBrowser;

  /// SSO confirmation: continue as the already signed-in account.
  /// English: "Continue as {name}".
  String continueAs(String name);

  /// English: "You are already signed in to another app on this device."
  String get ssoSubtitle;

  /// English: "Use another account".
  String get useAnotherAccount;

  /// English: "Too many attempts".
  String get lockedOutTitle;

  /// Lockout countdown after too many failed attempts.
  /// English: "Try again in {seconds} seconds."
  String lockedOutMessage(int seconds);

  /// English: "Try again".
  String get tryAgain;

  /// English: "Sign-in options could not be loaded."
  String get optionsUnavailable;

  /// English: "No sign-in method is available for this app."
  String get noMethods;

  /// English: "Sign-in is not configured."
  String get notConfigured;

  /// English: "The details you entered are not correct."
  String get feedbackInvalidCredential;

  /// English: "That code expired. Request a new one."
  String get feedbackCodeExpired;

  /// English: "Check your connection and try again."
  String get feedbackNetwork;

  /// English: "Signing in took too long. Start again."
  String get feedbackSessionExpired;

  /// English: "Your session ended. Sign in again."
  String get feedbackSessionRevoked;

  /// English: "That session is no longer available. Sign in to continue."
  String get feedbackSsoUnavailable;

  /// English: "That sign-in option is not available on this device."
  String get feedbackProviderUnavailable;

  /// English: "Something went wrong. Try again."
  String get feedbackUnexpected;

  /// English: "Enter your email".
  String get emailRequired;

  /// English: "Enter a valid email".
  String get emailInvalid;

  /// English: "Enter your password".
  String get passwordRequired;

  /// English: "Enter the code".
  String get codeRequired;

  /// English: "Terms".
  String get legalTermsLabel;

  /// English: "Privacy Policy".
  String get legalPrivacyLabel;

  /// Footer shown when both the terms-of-service and privacy-policy links are configured.
  /// English: "By continuing, you accept the {terms} and the {policy}."
  String legalFooterBoth(String terms, String policy);

  /// Footer shown when only the terms-of-service link is configured.
  /// English: "By continuing, you accept the {terms}."
  String legalFooterTermsOnly(String terms);

  /// Footer shown when only the privacy-policy link is configured.
  /// English: "By continuing, you accept the {policy}."
  String legalFooterPolicyOnly(String policy);

  /// Entry action that opens the access-code step.
  /// English: "I have an access code".
  String get useAccessCode;

  /// Title of the access-code step.
  /// English: "Access code".
  String get accessCodeTitle;

  /// Instructions of the access-code step.
  /// English: "Enter the access code you were given."
  String get accessCodeInstructions;

  /// Shape of an access code, shown as the field hint.
  /// English: "XXXX-XXXX".
  String get accessCodeHint;

  /// Field error: the access code is shorter than its fixed length.
  /// English: "Enter the {length} characters of the code".
  String accessCodeIncomplete(int length);

  /// The server refused the access code (unknown, expired, used or revoked — never told apart).
  /// English: "That access code is not valid: it may be mistyped, expired or already used. Check it or ask for a new one."
  String get feedbackInvalidAccessCode;

  /// Access codes are disabled for the application, or the server does not support them.
  /// English: "Access codes are not available for this app."
  String get feedbackAccessCodesUnavailable;

  /// The client has no DPoP key store, which access codes require.
  /// English: "This app is not set up to sign in with access codes."
  String get feedbackAccessCodeNotConfigured;

  /// Title of the passkey manager.
  /// English: "Passkeys".
  String get passkeysTitle;

  /// Subtitle of the passkey manager.
  /// English: "Sign in without a password using your device's screen lock."
  String get passkeysSubtitle;

  /// The signed-in user has no enrolled passkey.
  /// English: "You have no passkeys yet."
  String get passkeysEmpty;

  /// The passkey list could not be read.
  /// English: "Your passkeys could not be loaded."
  String get passkeysLoadFailed;

  /// The passkey manager is shown with nobody signed in.
  /// English: "Sign in to manage your passkeys."
  String get passkeysSignedOut;

  /// Action that enrolls a new passkey.
  /// English: "Add a passkey".
  String get addPasskey;

  /// Name shown for a passkey the user never named.
  /// English: "Passkey".
  String get passkeyUnnamed;

  /// When the passkey was enrolled.
  /// English: "Added {date}".
  String passkeyAddedOn(String date);

  /// When the passkey last signed the user in.
  /// English: "Last used {date}".
  String passkeyLastUsedOn(String date);

  /// Action that renames a passkey.
  /// English: "Rename".
  String get renamePasskey;

  /// Action that deletes a passkey.
  /// English: "Delete".
  String get deletePasskey;

  /// Label of the passkey name field.
  /// English: "Name".
  String get passkeyNameLabel;

  /// Field error: the passkey name is empty.
  /// English: "Enter a name".
  String get passkeyNameRequired;

  /// Confirms a dialog that saves a change.
  /// English: "Save".
  String get saveButton;

  /// Dismisses a dialog without changes.
  /// English: "Cancel".
  String get cancelButton;

  /// Title of the delete confirmation.
  /// English: "Delete this passkey?"
  String get deletePasskeyTitle;

  /// Body of the delete confirmation.
  /// English: "You will no longer be able to sign in with “{name}”."
  String deletePasskeyMessage(String name);

  /// Title shown while the user signs in again to add a passkey.
  /// English: "Confirm it's you".
  String get reauthenticateTitle;

  /// Explains why the user is asked to sign in again.
  /// English: "To add a passkey, sign in again."
  String get reauthenticateMessage;

  /// PasskeyFailureReason.notConfigured.
  /// English: "Passkeys are not set up in this app."
  String get feedbackPasskeyNotConfigured;

  /// PasskeyFailureReason.notSupported.
  /// English: "This device cannot use passkeys."
  String get feedbackPasskeyNotSupported;

  /// PasskeyFailureReason.noCredentialsAvailable.
  /// English: "No passkey is available on this device."
  String get feedbackPasskeyNoCredentials;

  /// PasskeyFailureReason.securityError.
  /// English: "This app is not allowed to use passkeys for this account."
  String get feedbackPasskeySecurityError;

  /// PasskeyFailureReason.domainNotAssociated.
  /// English: "This app is not linked to the passkey domain yet."
  String get feedbackPasskeyDomainNotAssociated;

  /// PasskeyFailureReason.alreadyRegistered.
  /// English: "This device already has a passkey for your account."
  String get feedbackPasskeyAlreadyRegistered;

  /// PasskeyFailureReason.timeout.
  /// English: "The passkey took too long to respond. Try again."
  String get feedbackPasskeyTimeout;

  /// PasskeyFailureReason.invalidResponse.
  /// English: "The device returned an invalid response. Try again."
  String get feedbackPasskeyInvalidResponse;

  /// PasskeyFailureReason.unknown.
  /// English: "The passkey could not be created."
  String get feedbackPasskeyFailed;

  /// Rename or delete of a passkey the server no longer has.
  /// English: "That passkey no longer exists."
  String get feedbackPasskeyNotFound;

  /// The passkey account API refused the call with a coded 403
  /// (PasskeyAccountRefused).
  /// English: "Passkeys are not available for this account."
  String get feedbackPasskeysUnavailable;

  /// The server still asks for a recent sign-in after one step-up.
  /// English: "Sign in again to add a passkey."
  String get feedbackReauthenticationRequired;

  /// The server answered 429 to a passkey request.
  /// English: "Too many attempts. Wait a moment and try again."
  String get feedbackRateLimited;
}
