import 'package:loginflow_auth/src/core/error/login_flow_error.dart';
import 'package:loginflow_auth/src/core/protocol/challenge/upstream_prompt.dart';
import 'package:loginflow_auth/src/core/protocol/challenge/upstream_token_type.dart';
import 'package:result_controller/result_controller.dart';

/// A provider token obtained natively, with how the server must interpret
/// it (`upstream_token_type`, `doc/server-contract.md` §5.4) and, on
/// Apple's first authorization only, the name it returned once (`name`
/// claims are omitted from `identityToken` and arrive out of band —
/// `upstream_user_name`).
class ObtainedUpstreamToken {
  /// Creates an [ObtainedUpstreamToken].
  const ObtainedUpstreamToken({
    required this.token,
    required this.tokenType,
    this.givenName,
    this.familyName,
  });

  /// The provider token.
  final String token;

  /// Whether [token] is an ID token or an access token.
  final UpstreamTokenType tokenType;

  /// Apple's given name, on the first authorization only.
  final String? givenName;

  /// Apple's family name, on the first authorization only.
  final String? familyName;

  /// A copy of this [ObtainedUpstreamToken] with the given fields replaced.
  ObtainedUpstreamToken copyWith({
    String? token,
    UpstreamTokenType? tokenType,
    String? givenName,
    String? familyName,
  }) => ObtainedUpstreamToken(
    token: token ?? this.token,
    tokenType: tokenType ?? this.tokenType,
    givenName: givenName ?? this.givenName,
    familyName: familyName ?? this.familyName,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ObtainedUpstreamToken &&
          token == other.token &&
          tokenType == other.tokenType &&
          givenName == other.givenName &&
          familyName == other.familyName;

  @override
  int get hashCode => Object.hash(token, tokenType, givenName, familyName);

  @override
  String toString() => 'ObtainedUpstreamToken(<redacted>)';
}

/// Obtains a federated provider token natively, without a browser.
///
/// Implemented by the optional `loginflow_auth_apple` /
/// `loginflow_auth_facebook` packages, so apps that do not offer a provider
/// do not depend on its SDK. [GoogleIdTokenSource] keeps its own narrower
/// interface for backward compatibility; `LoginFlowAuth` wraps it into this
/// shape internally.
abstract interface class UpstreamTokenSource {
  /// Whether this source can run its native ceremony on the current
  /// platform. `false` makes the library use the hosted page in the system
  /// browser instead — e.g. Apple sign-in on Android, where
  /// `sign_in_with_apple`'s own web flow is deliberately not used
  /// (`doc/decisions.md`).
  bool get isAvailable;

  /// Runs the provider's native ceremony for [prompt] and returns its token.
  /// Failures are `UpstreamFailed`, never exceptions.
  Future<Result<ObtainedUpstreamToken, LoginFlowError>> obtainToken(
    UpstreamPrompt prompt,
  );
}
