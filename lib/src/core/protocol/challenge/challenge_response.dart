import 'dart:convert';

import 'package:loginflow_auth/src/core/json/json_field_reader.dart';
import 'package:loginflow_auth/src/core/json/list_equality.dart';
import 'package:loginflow_auth/src/core/protocol/challenge/challenge_step.dart';
import 'package:loginflow_auth/src/core/protocol/challenge/step_error.dart';
import 'package:loginflow_auth/src/core/protocol/challenge/upstream_prompt.dart';

/// A response of the Authorization Challenge Endpoint
/// (draft-ietf-oauth-first-party-apps-04 §5.2).
sealed class ChallengeResponse {
  const ChallengeResponse();

  /// The JSON form of this [ChallengeResponse].
  Map<String, Object?> toJson();
}

/// 200: the authorization code to redeem at the token endpoint (§5.2.1).
final class ChallengeCodeIssued extends ChallengeResponse {
  /// Creates a [ChallengeCodeIssued].
  const ChallengeCodeIssued({required this.authorizationCode});

  /// Reads a [ChallengeCodeIssued] from its JSON form ([toJson]).
  factory ChallengeCodeIssued.fromJson(Map<String, Object?> json) =>
      ChallengeCodeIssued(
        authorizationCode: json.requireString('authorization_code'),
      );

  /// The single-use code, redeemed at once with the PKCE verifier.
  final String authorizationCode;

  /// A copy of this [ChallengeCodeIssued] with the given fields replaced.
  ChallengeCodeIssued copyWith({String? authorizationCode}) =>
      ChallengeCodeIssued(
        authorizationCode: authorizationCode ?? this.authorizationCode,
      );

  @override
  Map<String, Object?> toJson() => <String, Object?>{
    'authorization_code': authorizationCode,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ChallengeCodeIssued &&
          authorizationCode == other.authorizationCode;

  @override
  int get hashCode => authorizationCode.hashCode;

  @override
  String toString() => 'ChallengeCodeIssued(<redacted>)';
}

/// 403 `insufficient_authorization`: the user must complete [next] (§5.2.2).
final class ChallengeStepRequired extends ChallengeResponse {
  /// Creates a [ChallengeStepRequired].
  const ChallengeStepRequired({
    required this.authSession,
    required this.next,
    this.methods = const <ChallengeStep>[],
    this.stepError,
    this.upstream,
    this.options,
  });

  /// Reads a [ChallengeStepRequired] from its JSON form ([toJson]).
  factory ChallengeStepRequired.fromJson(Map<String, Object?> json) {
    final nextName = json.requireString('next');
    final next = ChallengeStep.fromWireName(nextName);
    if (next == null) {
      throw FormatException('Unknown challenge step "$nextName".');
    }
    final upstream = json.optionalObject('upstream');
    return ChallengeStepRequired(
      authSession: json.requireString('auth_session'),
      next: next,
      methods: List<ChallengeStep>.unmodifiable(
        json.stringList('methods').map(ChallengeStep.fromWireName).nonNulls,
      ),
      stepError: StepError.fromWireName(json.optionalString('step_error')),
      upstream: upstream == null ? null : UpstreamPrompt.fromJson(upstream),
      options: json.optionalObject('options'),
    );
  }

  /// The `error` value of this response on the wire.
  static const String errorCode = 'insufficient_authorization';

  /// Opaque, replaces any previous value (§5.3.1).
  final String authSession;

  /// The step to answer.
  final ChallengeStep next;

  /// Alternatives the user may switch to (for `select_method` and for
  /// "use a recovery code instead" on `totp`). Unknown names are dropped so a
  /// server that adds a method does not break older clients.
  final List<ChallengeStep> methods;

  /// Why the previous input was refused, when it was.
  final StepError? stepError;

  /// Present when [next] is [ChallengeStep.upstreamToken].
  final UpstreamPrompt? upstream;

  /// Present when [next] is [ChallengeStep.webauthnAssertion]: the
  /// `webauthn-rs` request/creation challenge, passed straight to
  /// `PasskeyAuthenticator.getAssertion`.
  final Map<String, Object?>? options;

  /// A copy of this [ChallengeStepRequired] with the given fields replaced.
  ChallengeStepRequired copyWith({
    String? authSession,
    ChallengeStep? next,
    List<ChallengeStep>? methods,
    StepError? stepError,
    UpstreamPrompt? upstream,
    Map<String, Object?>? options,
  }) => ChallengeStepRequired(
    authSession: authSession ?? this.authSession,
    next: next ?? this.next,
    methods: methods ?? this.methods,
    stepError: stepError ?? this.stepError,
    upstream: upstream ?? this.upstream,
    options: options ?? this.options,
  );

  @override
  Map<String, Object?> toJson() => <String, Object?>{
    'error': errorCode,
    'auth_session': authSession,
    'next': next.wireName,
    if (methods.isNotEmpty)
      'methods': methods.map((method) => method.wireName).toList(),
    'step_error': ?stepError?.wireName,
    'upstream': ?upstream?.toJson(),
    'options': ?options,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ChallengeStepRequired &&
          authSession == other.authSession &&
          next == other.next &&
          methods.hasSameValues(other.methods) &&
          stepError == other.stepError &&
          upstream == other.upstream &&
          _encodedOptions == other._encodedOptions;

  /// `options` is server-decoded JSON (`Map<String, Object?>`), which has no
  /// built-in deep equality; comparing the (deterministic, since both sides
  /// decode the same JSON text shape) re-encoding is simpler than hand-rolling
  /// a recursive map/list comparison for a field the library only forwards,
  /// never inspects.
  String? get _encodedOptions => options == null ? null : jsonEncode(options);

  @override
  int get hashCode => Object.hash(
    authSession,
    next,
    methods.valuesHash,
    stepError,
    upstream,
    _encodedOptions,
  );
}

/// 403 `redirect_to_web`: continue in the system browser (§5.2.2.1.1).
final class ChallengeRedirectToWeb extends ChallengeResponse {
  /// Creates a [ChallengeRedirectToWeb].
  const ChallengeRedirectToWeb({
    this.authSession,
    this.requestUri,
    this.expiresIn,
  });

  /// Reads a [ChallengeRedirectToWeb] from its JSON form ([toJson]).
  factory ChallengeRedirectToWeb.fromJson(Map<String, Object?> json) {
    final expiresIn = json.optionalInt('expires_in');
    return ChallengeRedirectToWeb(
      authSession: json.optionalString('auth_session'),
      requestUri: json.optionalString('request_uri'),
      expiresIn: expiresIn == null ? null : Duration(seconds: expiresIn),
    );
  }

  /// The `error` value of this response on the wire.
  static const String errorCode = 'redirect_to_web';

  /// The rotated `auth_session`, kept by the library while the browser runs.
  final String? authSession;

  /// A pushed authorization request reference (RFC 9126 §2.2).
  final String? requestUri;

  /// How long the `request_uri` stays usable.
  final Duration? expiresIn;

  /// A copy of this [ChallengeRedirectToWeb] with the given fields replaced.
  ChallengeRedirectToWeb copyWith({
    String? authSession,
    String? requestUri,
    Duration? expiresIn,
  }) => ChallengeRedirectToWeb(
    authSession: authSession ?? this.authSession,
    requestUri: requestUri ?? this.requestUri,
    expiresIn: expiresIn ?? this.expiresIn,
  );

  @override
  Map<String, Object?> toJson() => <String, Object?>{
    'error': errorCode,
    'auth_session': ?authSession,
    'request_uri': ?requestUri,
    'expires_in': ?expiresIn?.inSeconds,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ChallengeRedirectToWeb &&
          authSession == other.authSession &&
          requestUri == other.requestUri &&
          expiresIn == other.expiresIn;

  @override
  int get hashCode => Object.hash(authSession, requestUri, expiresIn);
}

/// 400 `invalid_session`: the `auth_session` is unknown or expired (§5.2.2).
final class ChallengeSessionInvalid extends ChallengeResponse {
  /// Creates a [ChallengeSessionInvalid].
  const ChallengeSessionInvalid();

  /// Reads a [ChallengeSessionInvalid] from its JSON form ([toJson]).
  factory ChallengeSessionInvalid.fromJson(Map<String, Object?> json) {
    if (json['error'] != errorCode) {
      throw const FormatException('Not an invalid_session response.');
    }
    return const ChallengeSessionInvalid();
  }

  /// The `error` value of this response on the wire.
  static const String errorCode = 'invalid_session';

  /// A copy of this [ChallengeSessionInvalid] with the given fields replaced.
  ChallengeSessionInvalid copyWith() => const ChallengeSessionInvalid();

  @override
  Map<String, Object?> toJson() => <String, Object?>{'error': errorCode};

  @override
  bool operator ==(Object other) => other is ChallengeSessionInvalid;

  @override
  int get hashCode => errorCode.hashCode;
}
