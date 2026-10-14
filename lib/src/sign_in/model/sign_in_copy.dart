import 'package:loginflow_auth/src/core/json/json_field_reader.dart';
import 'package:loginflow_auth/src/sign_in/model/localized_text.dart';

/// Branding texts that replace the built-in title and subtitle.
class SignInCopy {
  const SignInCopy({this.title, this.subtitle});

  factory SignInCopy.fromJson(Map<String, Object?> json) {
    final title = json.optionalObject('title');
    final subtitle = json.optionalObject('subtitle');
    return SignInCopy(
      title: title == null ? null : LocalizedText.fromJson(title),
      subtitle: subtitle == null ? null : LocalizedText.fromJson(subtitle),
    );
  }

  final LocalizedText? title;
  final LocalizedText? subtitle;

  SignInCopy copyWith({LocalizedText? title, LocalizedText? subtitle}) =>
      SignInCopy(
        title: title ?? this.title,
        subtitle: subtitle ?? this.subtitle,
      );

  Map<String, Object?> toJson() => <String, Object?>{
    'title': ?title?.toJson(),
    'subtitle': ?subtitle?.toJson(),
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SignInCopy && title == other.title && subtitle == other.subtitle;

  @override
  int get hashCode => Object.hash(title, subtitle);
}
