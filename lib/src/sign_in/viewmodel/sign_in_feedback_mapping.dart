import 'package:loginflow_auth/src/core/error/browser_failure_reason.dart';
import 'package:loginflow_auth/src/core/error/login_flow_error.dart';
import 'package:loginflow_auth/src/core/error/passkey_failure_reason.dart';
import 'package:loginflow_auth/src/core/error/upstream_failure_reason.dart';
import 'package:loginflow_auth/src/core/protocol/challenge/step_error.dart';
import 'package:loginflow_auth/src/core/state/sign_out_reason.dart';
import 'package:loginflow_auth/src/sign_in/model/sign_in_feedback.dart';

/// Which message a library error shows in the sign-in UI.
extension LoginFlowErrorFeedback on LoginFlowError {
  SignInFeedback toFeedback() => switch (this) {
    NetworkFailure() => SignInFeedback.network,
    SessionRevoked() => SignInFeedback.sessionRevoked,
    BrowserFailed(reason: BrowserFailureReason.cancelled) =>
      SignInFeedback.none,
    BrowserFailed(reason: BrowserFailureReason.unavailable) =>
      SignInFeedback.providerUnavailable,
    BrowserFailed(reason: BrowserFailureReason.failed) =>
      SignInFeedback.unexpected,
    UpstreamFailed(reason: UpstreamFailureReason.cancelled) =>
      SignInFeedback.none,
    UpstreamFailed(
      reason: UpstreamFailureReason.notConfigured ||
          UpstreamFailureReason.noCredential,
    ) =>
      SignInFeedback.providerUnavailable,
    UpstreamFailed(reason: UpstreamFailureReason.failed) =>
      SignInFeedback.unexpected,
    PasskeyFailed(reason: PasskeyFailureReason.userCancelled) =>
      SignInFeedback.none,
    PasskeyFailed(
      reason: PasskeyFailureReason.notConfigured ||
          PasskeyFailureReason.notSupported ||
          PasskeyFailureReason.noCredentialsAvailable ||
          PasskeyFailureReason.securityError ||
          PasskeyFailureReason.domainNotAssociated,
    ) =>
      SignInFeedback.providerUnavailable,
    PasskeyFailed(
      reason: PasskeyFailureReason.invalidResponse ||
          PasskeyFailureReason.alreadyRegistered ||
          PasskeyFailureReason.timeout ||
          PasskeyFailureReason.unknown,
    ) =>
      SignInFeedback.unexpected,
    InvalidAccessCode() => SignInFeedback.invalidAccessCode,
    AccessCodesUnavailable() => SignInFeedback.accessCodesUnavailable,
    ServerResponseInvalid() ||
    OAuthProtocolError() ||
    RateLimited() ||
    AccessCodeThrottled() ||
    DiscoveryInvalid() ||
    ConfigurationInvalid() ||
    IdTokenRejected() ||
    InsufficientAuthorization() ||
    ReauthenticationRequired() ||
    NotSignedIn() ||
    NoChallengeInProgress() ||
    AuthorizationResponseRejected() ||
    AuthorizationDenied() ||
    StorageFailure() ||
    UnsupportedByServer() ||
    StepUpRequired() ||
    InvalidTarget() ||
    OrganizationUnavailable() ||
    DelegationDenied() => SignInFeedback.unexpected,
  };
}

/// Which message a refused access-code redemption shows
/// (`LoginFlowAuth.signInWithAccessCode`, `doc/server-contract.md` §16).
/// Two errors mean something specific there: [ConfigurationInvalid] is the
/// client without the DPoP key store the method requires, and
/// [UnsupportedByServer] a server with no challenge endpoint to redeem the
/// code at. `AccessCodeThrottled` never reaches here: it is a lockout
/// countdown (`SignInViewModel`), not a message.
extension AccessCodeErrorFeedback on LoginFlowError {
  SignInFeedback toAccessCodeFeedback() => switch (this) {
    ConfigurationInvalid() => SignInFeedback.accessCodeNotConfigured,
    UnsupportedByServer() => SignInFeedback.accessCodesUnavailable,
    NetworkFailure() ||
    ServerResponseInvalid() ||
    OAuthProtocolError() ||
    RateLimited() ||
    DiscoveryInvalid() ||
    IdTokenRejected() ||
    InsufficientAuthorization() ||
    SessionRevoked() ||
    ReauthenticationRequired() ||
    NotSignedIn() ||
    NoChallengeInProgress() ||
    BrowserFailed() ||
    AuthorizationResponseRejected() ||
    AuthorizationDenied() ||
    StorageFailure() ||
    UpstreamFailed() ||
    PasskeyFailed() ||
    InvalidAccessCode() ||
    AccessCodeThrottled() ||
    AccessCodesUnavailable() ||
    StepUpRequired() ||
    InvalidTarget() ||
    OrganizationUnavailable() ||
    DelegationDenied() => toFeedback(),
  };
}

/// Which message explains a sign-out the user did not ask for.
extension SignOutReasonFeedback on SignOutReason {
  SignInFeedback toFeedback() => switch (this) {
    SignOutReason.sessionRevoked ||
    SignOutReason.deviceSessionEnded => SignInFeedback.sessionRevoked,
    SignOutReason.challengeExpired => SignInFeedback.sessionExpired,
    SignOutReason.ssoUnavailable => SignInFeedback.ssoUnavailable,
    SignOutReason.none ||
    SignOutReason.userRequested ||
    SignOutReason.loginRequired => SignInFeedback.none,
  };
}

/// Which message a refused step input shows.
extension StepErrorFeedback on StepError? {
  SignInFeedback toFeedback() => switch (this) {
    StepError.invalidCredential => SignInFeedback.invalidCredential,
    StepError.codeExpired => SignInFeedback.codeExpired,
    null => SignInFeedback.none,
  };
}
