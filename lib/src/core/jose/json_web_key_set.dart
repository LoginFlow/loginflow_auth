import 'package:loginflow_auth/src/core/jose/json_web_key.dart';
import 'package:loginflow_auth/src/core/json/list_equality.dart';

/// A JWK Set document (RFC 7517 §5).
class JsonWebKeySet {
  const JsonWebKeySet({required this.keys});

  /// Keys with an unsupported or malformed shape are skipped instead of
  /// failing the whole set, so one new key type at the issuer does not break
  /// verification with the keys this library understands (RFC 7517 §5).
  factory JsonWebKeySet.fromJson(Map<String, Object?> json) {
    final rawKeys = json['keys'];
    if (rawKeys is! List<Object?>) {
      throw const FormatException('Field "keys" must be an array.');
    }
    final keys = <JsonWebKey>[];
    for (final rawKey in rawKeys) {
      if (rawKey is Map<String, Object?>) {
        try {
          keys.add(JsonWebKey.fromJson(rawKey));
        } on FormatException {
          continue;
        }
      }
    }
    return JsonWebKeySet(keys: List<JsonWebKey>.unmodifiable(keys));
  }

  final List<JsonWebKey> keys;

  /// The key with [keyId] that may verify [algorithm], if any.
  JsonWebKey? keyFor({required String keyId, required String algorithm}) {
    for (final key in keys) {
      if (key.keyId == keyId && key.canVerify(algorithm)) {
        return key;
      }
    }
    return null;
  }

  JsonWebKeySet copyWith({List<JsonWebKey>? keys}) =>
      JsonWebKeySet(keys: keys ?? this.keys);

  Map<String, Object?> toJson() => <String, Object?>{
    'keys': keys.map((key) => key.toJson()).toList(),
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is JsonWebKeySet && keys.hasSameValues(other.keys);

  @override
  int get hashCode => keys.valuesHash;
}
