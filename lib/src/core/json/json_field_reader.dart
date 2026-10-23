/// Strict, typed reads over a decoded JSON object.
///
/// Every accessor throws a [FormatException] naming the offending field when
/// the value is missing or has the wrong type. Wire parsing converts that
/// exception into a typed error at the HTTP boundary, so a malformed server
/// response never travels further into the library.
extension JsonFieldReader on Map<String, Object?> {
  String requireString(String field) {
    final value = this[field];
    if (value is String && value.isNotEmpty) {
      return value;
    }
    throw FormatException('Field "$field" must be a non-empty string.');
  }

  String? optionalString(String field) {
    final value = this[field];
    if (value == null) {
      return null;
    }
    if (value is String) {
      return value.isEmpty ? null : value;
    }
    throw FormatException('Field "$field" must be a string.');
  }

  int requireInt(String field) {
    final value = this[field];
    if (value is int) {
      return value;
    }
    throw FormatException('Field "$field" must be an integer.');
  }

  int? optionalInt(String field) {
    final value = this[field];
    if (value == null) {
      return null;
    }
    if (value is int) {
      return value;
    }
    throw FormatException('Field "$field" must be an integer.');
  }

  bool optionalBool(String field, {required bool absent}) {
    final value = this[field];
    if (value == null) {
      return absent;
    }
    if (value is bool) {
      return value;
    }
    throw FormatException('Field "$field" must be a boolean.');
  }

  List<String> stringList(String field) {
    final value = this[field];
    if (value == null) {
      return const <String>[];
    }
    if (value is List<Object?> && value.every((entry) => entry is String)) {
      return List<String>.unmodifiable(value.cast<String>());
    }
    throw FormatException('Field "$field" must be an array of strings.');
  }

  /// Reads a claim that may be either a single string or an array of
  /// strings, as OpenID Connect Core §2 allows for `aud`.
  List<String> stringOrStringList(String field) {
    final value = this[field];
    if (value is String && value.isNotEmpty) {
      return List<String>.unmodifiable(<String>[value]);
    }
    if (value is List<Object?> &&
        value.isNotEmpty &&
        value.every((entry) => entry is String)) {
      return List<String>.unmodifiable(value.cast<String>());
    }
    throw FormatException(
      'Field "$field" must be a string or a non-empty array of strings.',
    );
  }

  Map<String, Object?>? optionalObject(String field) {
    final value = this[field];
    if (value == null) {
      return null;
    }
    if (value is Map<String, Object?>) {
      return value;
    }
    throw FormatException('Field "$field" must be an object.');
  }

  Map<String, Object?> requireObject(String field) {
    final value = optionalObject(field);
    if (value != null) {
      return value;
    }
    throw FormatException('Field "$field" must be an object.');
  }

  bool requireBool(String field) {
    final value = this[field];
    if (value is bool) {
      return value;
    }
    throw FormatException('Field "$field" must be a boolean.');
  }

  /// An array of objects; an absent field is an error, an empty array is not.
  List<Map<String, Object?>> objectList(String field) {
    final value = this[field];
    if (value is List<Object?> &&
        value.every((entry) => entry is Map<String, Object?>)) {
      return value.cast<Map<String, Object?>>();
    }
    throw FormatException('Field "$field" must be an array of objects.');
  }

  /// [optionalUtcDateTime] of a field that must be present.
  DateTime requireUtcDateTime(String field) =>
      optionalUtcDateTime(field) ??
      (throw FormatException('Field "$field" must be an ISO 8601 date-time.'));

  /// A UTC instant. LoginFlow's REST API serializes its `NaiveDateTime`
  /// values without an offset (`2026-10-23T09:00:00`), always in UTC; one
  /// without an offset is read as UTC, never as the device's local time.
  DateTime? optionalUtcDateTime(String field) {
    final value = optionalString(field);
    if (value == null) {
      return null;
    }
    final hasOffset = RegExp(r'(Z|[+-]\d{2}:?\d{2})$').hasMatch(value);
    final parsed = DateTime.tryParse(hasOffset ? value : '${value}Z');
    if (parsed == null) {
      throw FormatException('Field "$field" must be an ISO 8601 date-time.');
    }
    return parsed;
  }
}
