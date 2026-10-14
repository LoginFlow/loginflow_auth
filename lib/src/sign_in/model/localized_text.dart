import 'package:loginflow_auth/src/core/json/json_field_reader.dart';

/// A text the app provides in every language the UI supports.
class LocalizedText {
  const LocalizedText({required this.english, required this.spanish});

  factory LocalizedText.fromJson(Map<String, Object?> json) => LocalizedText(
    english: json.requireString('en'),
    spanish: json.requireString('es'),
  );

  final String english;
  final String spanish;

  /// The text for [languageCode]; English for any other language.
  String forLanguage(String languageCode) => switch (languageCode) {
    'es' => spanish,
    _ => english,
  };

  LocalizedText copyWith({String? english, String? spanish}) => LocalizedText(
    english: english ?? this.english,
    spanish: spanish ?? this.spanish,
  );

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
