import 'package:loginflow_auth/src/core/flow/authorization_attempt.dart';

/// What was current when a network request started: the session
/// generation, the attempt (by identity) and, for a step-up, the subject the
/// new ID token must keep. A response is applied only if all of it is still
/// current (`doc/decisions.md` D9).
///
/// Internal flow state, never serialized.
class FlowOrigin {
  const FlowOrigin({
    required this.generation,
    required this.attempt,
    this.stepUpSubject,
  });

  final int generation;
  final AuthorizationAttempt? attempt;
  final String? stepUpSubject;

  FlowOrigin withAttempt(AuthorizationAttempt next) => copyWith(attempt: next);

  FlowOrigin copyWith({
    int? generation,
    AuthorizationAttempt? attempt,
    String? stepUpSubject,
  }) => FlowOrigin(
    generation: generation ?? this.generation,
    attempt: attempt ?? this.attempt,
    stepUpSubject: stepUpSubject ?? this.stepUpSubject,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FlowOrigin &&
          generation == other.generation &&
          identical(attempt, other.attempt) &&
          stepUpSubject == other.stepUpSubject;

  @override
  int get hashCode =>
      Object.hash(generation, identityHashCode(attempt), stepUpSubject);
}
