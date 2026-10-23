import 'package:loginflow_auth/src/core/json/json_field_reader.dart';
import 'package:loginflow_auth/src/core/json/list_equality.dart';

/// A resource server's step-up demand (RFC 9470 §3): the
/// `insufficient_user_authentication` error of a `Bearer` challenge in
/// `WWW-Authenticate`, with its `acr_values` and/or `max_age`.
class StepUpRequirement {
  /// Creates a [StepUpRequirement].
  const StepUpRequirement({this.acrValues = const <String>[], this.maxAge});

  /// Reads a [StepUpRequirement] from its JSON form ([toJson]).
  factory StepUpRequirement.fromJson(Map<String, Object?> json) {
    final maxAge = json.optionalInt('max_age');
    return StepUpRequirement(
      acrValues: json.stringList('acr_values'),
      maxAge: maxAge == null ? null : Duration(seconds: maxAge),
    );
  }

  /// The `error` of the RFC 9470 challenge.
  static const String errorCode = 'insufficient_user_authentication';

  /// The `acr` values that would satisfy the server; empty: any recent sign-in.
  final List<String> acrValues;

  /// How recent the sign-in must be.
  final Duration? maxAge;

  /// The server asks for a STRONG sign-in (a second factor or a passkey:
  /// `acr_values` present), not only a recent one (`max_age` alone): the
  /// UI can say "confirm with your second factor" before the step-up.
  bool get isStrongRequired => acrValues.isNotEmpty;

  /// Reads a `WWW-Authenticate` header value; `null` when it is not a
  /// `Bearer` challenge with `error="insufficient_user_authentication"`.
  static StepUpRequirement? fromWwwAuthenticate(String header) {
    final trimmed = header.trim();
    if (!trimmed.toLowerCase().startsWith('bearer ')) {
      return null;
    }
    final parameters = <String, String>{};
    final pattern = RegExp(r'([A-Za-z_]+)\s*=\s*(?:"([^"]*)"|([^\s,]+))');
    for (final match in pattern.allMatches(trimmed.substring(7))) {
      final name = match.group(1);
      final value = match.group(2) ?? match.group(3);
      if (name != null && value != null) {
        parameters[name.toLowerCase()] = value;
      }
    }
    if (parameters['error'] != errorCode) {
      return null;
    }
    final maxAge = int.tryParse(parameters['max_age'] ?? '');
    final acrValues = parameters['acr_values']?.split(' ') ?? const <String>[];
    return StepUpRequirement(
      acrValues: List<String>.unmodifiable(
        acrValues.where((value) => value.isNotEmpty),
      ),
      maxAge: maxAge == null ? null : Duration(seconds: maxAge),
    );
  }

  /// A copy of this [StepUpRequirement] with the given fields replaced.
  StepUpRequirement copyWith({List<String>? acrValues, Duration? maxAge}) =>
      StepUpRequirement(
        acrValues: acrValues ?? this.acrValues,
        maxAge: maxAge ?? this.maxAge,
      );

  /// The JSON form of this [StepUpRequirement], read back by [StepUpRequirement.fromJson].
  Map<String, Object?> toJson() => <String, Object?>{
    'acr_values': acrValues,
    'max_age': ?maxAge?.inSeconds,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StepUpRequirement &&
          acrValues.hasSameValues(other.acrValues) &&
          maxAge == other.maxAge;

  @override
  int get hashCode => Object.hash(acrValues.valuesHash, maxAge);
}
