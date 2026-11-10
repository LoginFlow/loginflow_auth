import 'package:loginflow_auth/src/core/json/json_field_reader.dart';
import 'package:loginflow_auth/src/core/json/list_equality.dart';
import 'package:loginflow_auth/src/core/protocol/challenge/challenge_response.dart';
import 'package:loginflow_auth/src/core/protocol/challenge/challenge_step.dart';
import 'package:loginflow_auth/src/core/protocol/challenge/step_error.dart';
import 'package:loginflow_auth/src/core/state/phone_approval.dart';
import 'package:loginflow_auth/src/core/state/qr_sign_in.dart';

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
    this.phoneApproval,
    this.qrSignIn,
  });

  /// The prompt for a `403 insufficient_authorization` [response].
  factory ChallengePrompt.fromResponse(
    ChallengeStepRequired response, {
    String? loginHint,
    DateTime? resendAvailableAt,
    PhoneApproval? phoneApproval,
    QrSignIn? qrSignIn,
  }) => ChallengePrompt(
    step: response.next,
    alternatives: response.methods,
    stepError: response.stepError,
    loginHint: loginHint,
    resendAvailableAt: resendAvailableAt,
    phoneApproval: phoneApproval,
    qrSignIn: qrSignIn,
  );

  /// Reads a [ChallengePrompt] from its JSON form ([toJson]).
  factory ChallengePrompt.fromJson(Map<String, Object?> json) {
    final stepName = json.requireString('step');
    final step = ChallengeStep.fromWireName(stepName);
    if (step == null) {
      throw FormatException('Unknown challenge step "$stepName".');
    }
    final phoneApproval = json.optionalObject('phone_approval');
    final qrSignIn = json.optionalObject('qr_sign_in');
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
      phoneApproval: phoneApproval == null
          ? null
          : PhoneApproval.fromJson(phoneApproval),
      qrSignIn: qrSignIn == null ? null : QrSignIn.fromJson(qrSignIn),
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

  /// On the [ChallengeStep.devicePush] step while the request waits on the
  /// phone: the number to show and when it expires. `null` once it ended:
  /// then [stepError] is [StepError.denied] or [StepError.expired].
  final PhoneApproval? phoneApproval;

  /// On the [ChallengeStep.deviceQr] step while the QR waits to be
  /// scanned: what to render and when it expires. `null` once it ended:
  /// then [stepError] is [StepError.denied] or [StepError.expired].
  final QrSignIn? qrSignIn;

  /// A copy of this [ChallengePrompt] with the given fields replaced.
  ChallengePrompt copyWith({
    ChallengeStep? step,
    List<ChallengeStep>? alternatives,
    StepError? stepError,
    String? loginHint,
    DateTime? resendAvailableAt,
    PhoneApproval? phoneApproval,
    QrSignIn? qrSignIn,
  }) => ChallengePrompt(
    step: step ?? this.step,
    alternatives: alternatives ?? this.alternatives,
    stepError: stepError ?? this.stepError,
    loginHint: loginHint ?? this.loginHint,
    resendAvailableAt: resendAvailableAt ?? this.resendAvailableAt,
    phoneApproval: phoneApproval ?? this.phoneApproval,
    qrSignIn: qrSignIn ?? this.qrSignIn,
  );

  /// The JSON form of this [ChallengePrompt], read back by [ChallengePrompt.fromJson].
  Map<String, Object?> toJson() => <String, Object?>{
    'step': step.wireName,
    'alternatives': alternatives.map((step) => step.wireName).toList(),
    'step_error': ?stepError?.wireName,
    'login_hint': ?loginHint,
    'resend_available_at': ?resendAvailableAt?.toUtc().toIso8601String(),
    'phone_approval': ?phoneApproval?.toJson(),
    'qr_sign_in': ?qrSignIn?.toJson(),
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ChallengePrompt &&
          step == other.step &&
          alternatives.hasSameValues(other.alternatives) &&
          stepError == other.stepError &&
          loginHint == other.loginHint &&
          resendAvailableAt == other.resendAvailableAt &&
          phoneApproval == other.phoneApproval &&
          qrSignIn == other.qrSignIn;

  @override
  int get hashCode => Object.hash(
    step,
    alternatives.valuesHash,
    stepError,
    loginHint,
    resendAvailableAt,
    phoneApproval,
    qrSignIn,
  );
}
