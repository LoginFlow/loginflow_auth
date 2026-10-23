import 'package:loginflow_auth/src/core/error/authorization_response_problem.dart';
import 'package:loginflow_auth/src/core/error/browser_failure_reason.dart';
import 'package:loginflow_auth/src/core/error/delegation_denial_code.dart';
import 'package:loginflow_auth/src/core/error/id_token_failure.dart';
import 'package:loginflow_auth/src/core/error/passkey_failure_reason.dart';
import 'package:loginflow_auth/src/core/error/upstream_failure_reason.dart';
import 'package:loginflow_auth/src/core/protocol/challenge/challenge_response.dart';
import 'package:loginflow_auth/src/core/protocol/challenge/upstream_provider.dart';
import 'package:loginflow_auth/src/core/protocol/step_up/step_up_requirement.dart';

/// Every expected failure the library reports, as the `E` of `Result<T, E>`.
///
/// Errors are values: they are compared in tests and switched over
/// exhaustively by callers. They are never serialized, so they carry no
/// `toJson`/`fromJson`. [message] is developer-facing text for logs and never
/// contains a token, secret or credential.
sealed class LoginFlowError {
  const LoginFlowError();

  /// Developer-facing text for logs; never a token, secret or credential.
  String get message;
}

/// The request never produced an HTTP response (DNS, TLS, timeout, offline).
final class NetworkFailure extends LoginFlowError {
  /// Creates a [NetworkFailure].
  const NetworkFailure({required this.description});

  /// What went wrong, for logs.
  final String description;

  @override
  String get message => 'Network failure: $description';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is NetworkFailure && description == other.description;

  @override
  int get hashCode => Object.hash(NetworkFailure, description);
}

/// The server answered with something outside the contract.
final class ServerResponseInvalid extends LoginFlowError {
  /// Creates a [ServerResponseInvalid].
  const ServerResponseInvalid({
    required this.statusCode,
    required this.description,
  });

  /// The HTTP status of the reply.
  final int statusCode;

  /// What went wrong, for logs.
  final String description;

  @override
  String get message =>
      'Unexpected server response ($statusCode): $description';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ServerResponseInvalid &&
          statusCode == other.statusCode &&
          description == other.description;

  @override
  int get hashCode =>
      Object.hash(ServerResponseInvalid, statusCode, description);
}

/// A standard OAuth error response (RFC 6749 §5.2), e.g. `invalid_grant`.
final class OAuthProtocolError extends LoginFlowError {
  /// Creates an [OAuthProtocolError].
  const OAuthProtocolError({
    required this.statusCode,
    required this.code,
    this.description,
  });

  /// The HTTP status of the reply.
  final int statusCode;

  /// The `error` parameter value.
  final String code;

  /// The `error_description` parameter value, when present.
  final String? description;

  @override
  String get message => 'OAuth error $code ($statusCode)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is OAuthProtocolError &&
          statusCode == other.statusCode &&
          code == other.code &&
          description == other.description;

  @override
  int get hashCode =>
      Object.hash(OAuthProtocolError, statusCode, code, description);
}

/// HTTP 429: too many attempts for this account, IP or auth session.
final class RateLimited extends LoginFlowError {
  /// Creates a [RateLimited].
  const RateLimited({this.retryAfter});

  /// From the `Retry-After` header, when the server sent one.
  final Duration? retryAfter;

  @override
  String get message => 'Rate limited (retry after ${retryAfter?.inSeconds}s)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RateLimited && retryAfter == other.retryAfter;

  @override
  int get hashCode => Object.hash(RateLimited, retryAfter);
}

/// The discovery document is unreachable, malformed, or for another issuer.
final class DiscoveryInvalid extends LoginFlowError {
  /// Creates a [DiscoveryInvalid].
  const DiscoveryInvalid({required this.description});

  /// What went wrong, for logs.
  final String description;

  @override
  String get message => 'Invalid discovery document: $description';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DiscoveryInvalid && description == other.description;

  @override
  int get hashCode => Object.hash(DiscoveryInvalid, description);
}

/// The app's [LoginFlowConfig] is unusable (insecure issuer, malformed or
/// disallowed redirect URI).
final class ConfigurationInvalid extends LoginFlowError {
  /// Creates a [ConfigurationInvalid].
  const ConfigurationInvalid({required this.description});

  /// What went wrong, for logs.
  final String description;

  @override
  String get message => 'Invalid configuration: $description';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ConfigurationInvalid && description == other.description;

  @override
  int get hashCode => Object.hash(ConfigurationInvalid, description);
}

/// An ID token failed validation and was not trusted.
final class IdTokenRejected extends LoginFlowError {
  /// Creates an [IdTokenRejected].
  const IdTokenRejected({required this.reason});

  /// Which check the ID token failed.
  final IdTokenFailure reason;

  @override
  String get message => 'ID token rejected: ${reason.name}';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is IdTokenRejected && reason == other.reason;

  @override
  int get hashCode => Object.hash(IdTokenRejected, reason);
}

/// The token endpoint asked for more user interaction before issuing tokens
/// (draft-ietf-oauth-first-party-apps-04 §6.2).
final class InsufficientAuthorization extends LoginFlowError {
  /// Creates an [InsufficientAuthorization].
  const InsufficientAuthorization({required this.challenge});

  /// The step the server asks for.
  final ChallengeStepRequired challenge;

  @override
  String get message =>
      'Insufficient authorization: ${challenge.next.wireName}';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is InsufficientAuthorization && challenge == other.challenge;

  @override
  int get hashCode => Object.hash(InsufficientAuthorization, challenge);
}

/// The refresh token was rejected (expired, revoked, or reused). The library
/// already cleared the local session.
final class SessionRevoked extends LoginFlowError {
  /// Creates a [SessionRevoked].
  const SessionRevoked();

  @override
  String get message => 'The session was revoked by the server.';

  @override
  bool operator ==(Object other) => other is SessionRevoked;

  @override
  int get hashCode => (SessionRevoked).hashCode;
}

/// A refresh needs the user to authenticate again; the state is now
/// `ChallengeRequired` with purpose `reauthentication`.
final class ReauthenticationRequired extends LoginFlowError {
  /// Creates a [ReauthenticationRequired].
  const ReauthenticationRequired();

  @override
  String get message => 'The server requires the user to authenticate again.';

  @override
  bool operator ==(Object other) => other is ReauthenticationRequired;

  @override
  int get hashCode => (ReauthenticationRequired).hashCode;
}

/// The operation needs a signed-in session and there is none.
final class NotSignedIn extends LoginFlowError {
  /// Creates a [NotSignedIn].
  const NotSignedIn();

  @override
  String get message => 'No user is signed in.';

  @override
  bool operator ==(Object other) => other is NotSignedIn;

  @override
  int get hashCode => (NotSignedIn).hashCode;
}

/// A challenge step was submitted while no sign-in was in progress.
final class NoChallengeInProgress extends LoginFlowError {
  /// Creates a [NoChallengeInProgress].
  const NoChallengeInProgress();

  @override
  String get message => 'No sign-in challenge is in progress.';

  @override
  bool operator ==(Object other) => other is NoChallengeInProgress;

  @override
  int get hashCode => (NoChallengeInProgress).hashCode;
}

/// The system browser step failed or was cancelled.
final class BrowserFailed extends LoginFlowError {
  /// Creates a [BrowserFailed].
  const BrowserFailed({required this.reason, this.description});

  /// Why the browser step did not complete.
  final BrowserFailureReason reason;

  /// Extra detail, for logs.
  final String? description;

  @override
  String get message => 'Browser step failed: ${reason.name}';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BrowserFailed &&
          reason == other.reason &&
          description == other.description;

  @override
  int get hashCode => Object.hash(BrowserFailed, reason, description);
}

/// A redirect back from the authorization endpoint failed validation.
final class AuthorizationResponseRejected extends LoginFlowError {
  /// Creates an [AuthorizationResponseRejected].
  const AuthorizationResponseRejected({required this.problem});

  /// What was wrong with the callback.
  final AuthorizationResponseProblem problem;

  @override
  String get message => 'Authorization response rejected: ${problem.name}';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AuthorizationResponseRejected && problem == other.problem;

  @override
  int get hashCode => Object.hash(AuthorizationResponseRejected, problem);
}

/// The authorization endpoint returned an `error` (RFC 6749 §4.1.2.1).
final class AuthorizationDenied extends LoginFlowError {
  /// Creates an [AuthorizationDenied].
  const AuthorizationDenied({required this.code, this.description});

  /// The `error` parameter of the callback (OpenID Connect Core §3.1.2.6).
  final String code;

  /// Extra detail, for logs.
  final String? description;

  @override
  String get message => 'Authorization denied: $code';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AuthorizationDenied &&
          code == other.code &&
          description == other.description;

  @override
  int get hashCode => Object.hash(AuthorizationDenied, code, description);
}

/// Secure storage on the device failed.
final class StorageFailure extends LoginFlowError {
  /// Creates a [StorageFailure].
  const StorageFailure({required this.description});

  /// What went wrong, for logs.
  final String description;

  @override
  String get message => 'Storage failure: $description';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StorageFailure && description == other.description;

  @override
  int get hashCode => Object.hash(StorageFailure, description);
}

/// The server's discovery document does not advertise a needed capability.
final class UnsupportedByServer extends LoginFlowError {
  /// Creates an [UnsupportedByServer].
  const UnsupportedByServer({required this.feature});

  /// The discovery field or capability that is missing.
  final String feature;

  @override
  String get message => 'Not supported by the server: $feature';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UnsupportedByServer && feature == other.feature;

  @override
  int get hashCode => Object.hash(UnsupportedByServer, feature);
}

/// A federated provider step could not produce a token.
final class UpstreamFailed extends LoginFlowError {
  /// Creates an [UpstreamFailed].
  const UpstreamFailed({required this.provider, required this.reason});

  /// The provider whose sign-in failed.
  final UpstreamProvider provider;

  /// Why the native provider ceremony failed.
  final UpstreamFailureReason reason;

  @override
  String get message => 'Upstream ${provider.wireName} failed: ${reason.name}';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UpstreamFailed &&
          provider == other.provider &&
          reason == other.reason;

  @override
  int get hashCode => Object.hash(UpstreamFailed, provider, reason);
}

/// A passkey (WebAuthn) ceremony could not produce a credential.
final class PasskeyFailed extends LoginFlowError {
  /// Creates a [PasskeyFailed].
  const PasskeyFailed({required this.reason, this.code, this.description});

  /// Why the passkey ceremony failed.
  final PasskeyFailureReason reason;

  /// The platform's own error code (a WebAuthn `DOMException` name such as
  /// `SecurityError`, or the passkey plugin's code), when it reported one.
  /// For logs only: switch over [reason].
  final String? code;

  /// The platform's own error message, when it reported one. For logs only.
  final String? description;

  @override
  String get message => code == null
      ? 'Passkey ceremony failed: ${reason.name}'
      : 'Passkey ceremony failed: ${reason.name} ($code)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PasskeyFailed &&
          reason == other.reason &&
          code == other.code &&
          description == other.description;

  @override
  int get hashCode => Object.hash(PasskeyFailed, reason, code, description);
}

/// The access code was not accepted: unknown, expired, already used,
/// revoked or malformed. The server answers the same `invalid_grant` for
/// every case so a response never tells which codes exist
/// (`doc/server-contract.md` §16).
final class InvalidAccessCode extends LoginFlowError {
  /// Creates an [InvalidAccessCode].
  const InvalidAccessCode();

  @override
  String get message => 'The access code is invalid, expired or used.';

  @override
  bool operator ==(Object other) => other is InvalidAccessCode;

  @override
  int get hashCode => (InvalidAccessCode).hashCode;
}

/// Too many failed access-code redemptions from this device or address, or
/// for the whole application (`429`/`slow_down`, `doc/server-contract.md`
/// §16). Wait [retryAfter] before the next attempt.
final class AccessCodeThrottled extends LoginFlowError {
  /// Creates an [AccessCodeThrottled].
  const AccessCodeThrottled({this.retryAfter});

  /// From the `Retry-After` header, when the server sent one.
  final Duration? retryAfter;

  @override
  String get message =>
      'Access-code sign-in throttled (retry after ${retryAfter?.inSeconds}s)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AccessCodeThrottled && retryAfter == other.retryAfter;

  @override
  int get hashCode => Object.hash(AccessCodeThrottled, retryAfter);
}

/// The application does not accept access codes: disabled in its settings
/// (`access_codes_disabled`), or a server that does not implement the
/// `access_code` method (`doc/server-contract.md` §16).
final class AccessCodesUnavailable extends LoginFlowError {
  /// Creates an [AccessCodesUnavailable].
  const AccessCodesUnavailable();

  @override
  String get message => 'Access codes are not available for this app.';

  @override
  bool operator ==(Object other) => other is AccessCodesUnavailable;

  @override
  int get hashCode => (AccessCodesUnavailable).hashCode;
}

/// A LoginFlow account API refused the access token because the user's
/// authentication is too old or too weak for that operation (RFC 9470:
/// `401` with `WWW-Authenticate: Bearer
/// error="insufficient_user_authentication"`), e.g. enrolling a passkey
/// more than 300 s after signing in. Re-authenticate with
/// `LoginFlowAuth.stepUp(requirement)`, then retry the same operation.
final class StepUpRequired extends LoginFlowError {
  /// Creates a [StepUpRequired].
  const StepUpRequired({required this.requirement});

  /// The server's demand (`acr_values`, `max_age`), ready for
  /// `LoginFlowAuth.stepUp`.
  final StepUpRequirement requirement;

  @override
  String get message =>
      'Step-up required (max_age: ${requirement.maxAge?.inSeconds}s, '
      'acr_values: ${requirement.acrValues.join(' ')})';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StepUpRequired && requirement == other.requirement;

  @override
  int get hashCode => Object.hash(StepUpRequired, requirement);
}

/// The server does not issue tokens for [api] to this client
/// (`invalid_target`, RFC 8707 §2): the API is not linked to the client, or
/// no longer exists. The session is untouched; tokens for the other APIs
/// keep working.
final class InvalidTarget extends LoginFlowError {
  /// Creates an [InvalidTarget].
  const InvalidTarget({required this.api});

  /// The API audience that was asked for (the `resource` value).
  final String api;

  @override
  String get message => 'The server refused tokens for the API $api.';

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is InvalidTarget && api == other.api;

  @override
  int get hashCode => Object.hash(InvalidTarget, api);
}

/// `LoginFlowAuth.switchOrganization` asked for an organization where the
/// user has no active assignment (`invalid_grant` on the refresh with
/// `organization`, `doc/server-contract.md` §17). The session keeps its
/// active organization.
final class OrganizationUnavailable extends LoginFlowError {
  /// Creates an [OrganizationUnavailable].
  const OrganizationUnavailable({required this.organizationId});

  /// The organization that was asked for.
  final String organizationId;

  @override
  String get message => 'The organization $organizationId is not available.';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is OrganizationUnavailable &&
          organizationId == other.organizationId;

  @override
  int get hashCode => Object.hash(OrganizationUnavailable, organizationId);
}

/// LoginFlow refused a members call (`doc/server-contract.md` §18): [code]
/// names the delegation rule, so the UI shows why without parsing text.
final class DelegationDenied extends LoginFlowError {
  /// Creates a [DelegationDenied].
  const DelegationDenied({required this.code, required this.statusCode});

  /// The delegation rule that refused the call.
  final DelegationDenialCode code;

  /// `403`, `404`, `409` or `422`, as the server answered.
  final int statusCode;

  @override
  String get message => 'Members call refused ($statusCode): ${code.wireName}';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DelegationDenied &&
          code == other.code &&
          statusCode == other.statusCode;

  @override
  int get hashCode => Object.hash(DelegationDenied, code, statusCode);
}

/// An email-change confirmation was refused (`401 INVALID_CODE`,
/// `doc/server-contract.md` §19): a wrong, expired, used or burned code —
/// either of the two —, a missing code for the current address, no open
/// change, or a new address taken since the start. The server answers the
/// same for every case, so neither does this error; a code that is not
/// 6 digits (`422`) is this error too.
final class InvalidEmailChangeCode extends LoginFlowError {
  /// Creates an [InvalidEmailChangeCode].
  const InvalidEmailChangeCode();

  @override
  String get message => 'The email-change code is invalid or has expired.';

  @override
  bool operator ==(Object other) => other is InvalidEmailChangeCode;

  @override
  int get hashCode => (InvalidEmailChangeCode).hashCode;
}

/// The new address of an email change was refused (`422`,
/// `doc/server-contract.md` §19): malformed, a disposable mailbox, or the
/// account's current email.
final class InvalidEmailAddress extends LoginFlowError {
  /// Creates an [InvalidEmailAddress].
  const InvalidEmailAddress();

  @override
  String get message => 'The new email address is not valid for this account.';

  @override
  bool operator ==(Object other) => other is InvalidEmailAddress;

  @override
  int get hashCode => (InvalidEmailAddress).hashCode;
}
