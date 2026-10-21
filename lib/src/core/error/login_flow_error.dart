import 'package:loginflow_auth/src/core/error/authorization_response_problem.dart';
import 'package:loginflow_auth/src/core/error/browser_failure_reason.dart';
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

  String get message;
}

/// The request never produced an HTTP response (DNS, TLS, timeout, offline).
final class NetworkFailure extends LoginFlowError {
  const NetworkFailure({required this.description});

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
  const ServerResponseInvalid({
    required this.statusCode,
    required this.description,
  });

  final int statusCode;
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
  const OAuthProtocolError({
    required this.statusCode,
    required this.code,
    this.description,
  });

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
  const DiscoveryInvalid({required this.description});

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
  const ConfigurationInvalid({required this.description});

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
  const IdTokenRejected({required this.reason});

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
  const InsufficientAuthorization({required this.challenge});

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
  const BrowserFailed({required this.reason, this.description});

  final BrowserFailureReason reason;
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
  const AuthorizationResponseRejected({required this.problem});

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
  const AuthorizationDenied({required this.code, this.description});

  final String code;
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
  const StorageFailure({required this.description});

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
  const UpstreamFailed({required this.provider, required this.reason});

  final UpstreamProvider provider;
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
  const PasskeyFailed({required this.reason, this.code, this.description});

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

/// A LoginFlow account API refused the access token because the user's
/// authentication is too old or too weak for that operation (RFC 9470:
/// `401` with `WWW-Authenticate: Bearer
/// error="insufficient_user_authentication"`), e.g. enrolling a passkey
/// more than 300 s after signing in. Re-authenticate with
/// `LoginFlowAuth.stepUp(requirement)`, then retry the same operation.
final class StepUpRequired extends LoginFlowError {
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
