import 'package:loginflow_auth/src/core/json/json_field_reader.dart';
import 'package:loginflow_auth/src/core/json/list_equality.dart';
import 'package:loginflow_auth/src/core/protocol/challenge/challenge_response.dart';
import 'package:loginflow_auth/src/core/protocol/challenge/challenge_step.dart';
import 'package:loginflow_auth/src/core/protocol/challenge/step_error.dart';

/// What the UI must ask for next. The opaque `auth_session` stays inside the
/// library and is never exposed.
class ChallengePrompt {
  /// Creates a [ChallengePrompt].
  const ChallengePrompt({
    required this.step,
    this.alternatives = const <ChallengeStep>[],
    this.stepError,
    this.loginHint,
    this.resendAvailableAt,
  });

  /// The prompt for a `403 insufficient_authorization` [response].
  factory ChallengePrompt.fromResponse(
    ChallengeStepRequired response, {
    String? loginHint,
    DateTime? resendAvailableAt,
  }) => ChallengePrompt(
    step: response.next,
    alternatives: response.methods,
    stepError: response.stepError,
    loginHint: loginHint,
    resendAvailableAt: resendAvailableAt,
  );

  /// Reads a [ChallengePrompt] from its JSON form ([toJson]).
  factory ChallengePrompt.fromJson(Map<String, Object?> json) {
    final stepName = json.requireString('step');
    final step = ChallengeStep.fromWireName(stepName);
    if (step == null) {
      throw FormatException('Unknown challenge step "$stepName".');
    }
    return ChallengePrompt(
      step: step,
      alternatives: List<ChallengeStep>.unmodifiable(
        json
            .stringList('alternatives')
            .map(ChallengeStep.fromWireName)
            .nonNulls,
      ),
      stepError: StepError.fromWireName(json.optionalString('step_error')),
      loginHint: json.optionalString('login_hint'),
      resendAvailableAt: json.optionalUtcDateTime('resend_available_at'),
    );
  }

  /// The step to answer.
  final ChallengeStep step;

  /// Other steps the user may switch to (method list, recovery code).
  final List<ChallengeStep> alternatives;

  /// Why the previous input was refused, if it was.
  final StepError? stepError;

  /// The identifier typed by the user, for display ("code sent to …").
  final String? loginHint;

  /// When `LoginFlowAuth.resendEmailOtp` may ask for another code, in UTC:
  /// set on the [ChallengeStep.emailOtp] step, `null` on any other. A
  /// wrong code keeps it; a successful resend moves it one
  /// `LoginFlowConfig.emailCodeResendCooldown` ahead. Show the wait with
  /// `LoginFlowAuth.emailOtpResendWait`.
  final DateTime? resendAvailableAt;

  /// A copy of this [ChallengePrompt] with the given fields replaced.
  ChallengePrompt copyWith({
    ChallengeStep? step,
    List<ChallengeStep>? alternatives,
    StepError? stepError,
    String? loginHint,
    DateTime? resendAvailableAt,
  }) => ChallengePrompt(
    step: step ?? this.step,
    alternatives: alternatives ?? this.alternatives,
    stepError: stepError ?? this.stepError,
    loginHint: loginHint ?? this.loginHint,
    resendAvailableAt: resendAvailableAt ?? this.resendAvailableAt,
  );

  /// The JSON form of this [ChallengePrompt], read back by [ChallengePrompt.fromJson].
  Map<String, Object?> toJson() => <String, Object?>{
    'step': step.wireName,
    'alternatives': alternatives.map((step) => step.wireName).toList(),
    'step_error': ?stepError?.wireName,
    'login_hint': ?loginHint,
    'resend_available_at': ?resendAvailableAt?.toUtc().toIso8601String(),
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ChallengePrompt &&
          step == other.step &&
          alternatives.hasSameValues(other.alternatives) &&
          stepError == other.stepError &&
          loginHint == other.loginHint &&
          resendAvailableAt == other.resendAvailableAt;

  @override
  int get hashCode => Object.hash(
    step,
    alternatives.valuesHash,
    stepError,
    loginHint,
    resendAvailableAt,
  );
}
