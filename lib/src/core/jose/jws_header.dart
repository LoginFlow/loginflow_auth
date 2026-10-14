import 'package:loginflow_auth/src/core/json/json_field_reader.dart';
import 'package:loginflow_auth/src/core/json/list_equality.dart';

/// The JOSE header members the validator reads (RFC 7515 §4.1).
class JwsHeader {
  const JwsHeader({
    required this.algorithm,
    this.keyId,
    this.type,
    this.critical = const <String>[],
  });

  factory JwsHeader.fromJson(Map<String, Object?> json) => JwsHeader(
    algorithm: json.requireString('alg'),
    keyId: json.optionalString('kid'),
    type: json.optionalString('typ'),
    critical: json.stringList('crit'),
  );

  final String algorithm;
  final String? keyId;
  final String? type;
  final List<String> critical;

  JwsHeader copyWith({
    String? algorithm,
    String? keyId,
    String? type,
    List<String>? critical,
  }) => JwsHeader(
    algorithm: algorithm ?? this.algorithm,
    keyId: keyId ?? this.keyId,
    type: type ?? this.type,
    critical: critical ?? this.critical,
  );

  Map<String, Object?> toJson() => <String, Object?>{
    'alg': algorithm,
    'kid': ?keyId,
    'typ': ?type,
    if (critical.isNotEmpty) 'crit': critical,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is JwsHeader &&
          algorithm == other.algorithm &&
          keyId == other.keyId &&
          type == other.type &&
          critical.hasSameValues(other.critical);

  @override
  int get hashCode => Object.hash(algorithm, keyId, type, critical.valuesHash);
}
