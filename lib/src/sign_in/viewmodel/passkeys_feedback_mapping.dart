import 'package:loginflow_auth/src/core/error/login_flow_error.dart';
import 'package:loginflow_auth/src/core/error/passkey_failure_reason.dart';
import 'package:loginflow_auth/src/sign_in/model/passkeys_feedback.dart';

/// Which message a library error shows in the passkey manager. A
/// [PasskeyFailed] keeps its real reason; a sheet the user dismissed shows
/// nothing.
extension PasskeysErrorFeedback on LoginFlowError {
  PasskeysFeedback toPasskeysFeedback() => switch (this) {
    PasskeyFailed(:final reason) => reason.toPasskeysFeedback(),
    NetworkFailure() => PasskeysFeedback.network,
    SessionRevoked() ||
    NotSignedIn() ||
    ReauthenticationRequired() => PasskeysFeedback.sessionEnded,
    RateLimited() => PasskeysFeedback.rateLimited,
    ServerResponseInvalid(statusCode: 404) => PasskeysFeedback.notFound,
    StepUpRequired() => PasskeysFeedback.reauthenticationRequired,
    ServerResponseInvalid() ||
    OAuthProtocolError() ||
    DiscoveryInvalid() ||
    ConfigurationInvalid() ||
    IdTokenRejected() ||
    InsufficientAuthorization() ||
    NoChallengeInProgress() ||
    BrowserFailed() ||
    AuthorizationResponseRejected() ||
    AuthorizationDenied() ||
    StorageFailure() ||
    UnsupportedByServer() ||
    UpstreamFailed() ||
    InvalidAccessCode() ||
    AccessCodeThrottled() ||
    AccessCodesUnavailable() ||
    InvalidTarget() ||
    OrganizationUnavailable() => PasskeysFeedback.unexpected,
  };
}

/// One message per ceremony failure (`PasskeyFailureReason`).
extension PasskeyFailureFeedback on PasskeyFailureReason {
  PasskeysFeedback toPasskeysFeedback() => switch (this) {
    PasskeyFailureReason.userCancelled => PasskeysFeedback.none,
    PasskeyFailureReason.notConfigured => PasskeysFeedback.passkeyNotConfigured,
    PasskeyFailureReason.notSupported => PasskeysFeedback.passkeyNotSupported,
    PasskeyFailureReason.noCredentialsAvailable =>
      PasskeysFeedback.passkeyNoCredentials,
    PasskeyFailureReason.securityError => PasskeysFeedback.passkeySecurityError,
    PasskeyFailureReason.domainNotAssociated =>
      PasskeysFeedback.passkeyDomainNotAssociated,
    PasskeyFailureReason.alreadyRegistered =>
      PasskeysFeedback.passkeyAlreadyRegistered,
    PasskeyFailureReason.timeout => PasskeysFeedback.passkeyTimeout,
    PasskeyFailureReason.invalidResponse =>
      PasskeysFeedback.passkeyInvalidResponse,
    PasskeyFailureReason.unknown => PasskeysFeedback.passkeyFailed,
  };
}
