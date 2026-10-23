import 'package:loginflow_auth/src/core/json/json_field_reader.dart';

/// A text the app provides in every language the UI supports.
class LocalizedText {
  /// Creates a [LocalizedText].
  const LocalizedText({required this.english, required this.spanish});

  /// Reads a [LocalizedText] from its JSON form ([toJson]).
  factory LocalizedText.fromJson(Map<String, Object?> json) => LocalizedText(
    english: json.requireString('en'),
    spanish: json.requireString('es'),
  );

  /// The text in English.
  final String english;

  /// The text in Spanish.
  final String spanish;

  /// The text for [languageCode]; English for any other language.
  String forLanguage(String languageCode) => switch (languageCode) {
    'es' => spanish,
    _ => english,
  };

  /// A copy of this [LocalizedText] with the given fields replaced.
  LocalizedText copyWith({String? english, String? spanish}) => LocalizedText(
    english: english ?? this.english,
    spanish: spanish ?? this.spanish,
  );

  /// The JSON form of this [LocalizedText], read back by [LocalizedText.fromJson].
  Map<String, Object?> toJson() => <String, Object?>{
    'en': english,
    'es': spanish,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LocalizedText &&
          english == other.english &&
          spanish == other.spanish;

  @override
  int get hashCode => Object.hash(english, spanish);
}
