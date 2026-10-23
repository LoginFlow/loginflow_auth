import 'package:loginflow_auth/src/core/json/json_field_reader.dart';
import 'package:loginflow_auth/src/sign_in/model/localized_text.dart';

/// Branding texts that replace the built-in title and subtitle.
class SignInCopy {
  /// Creates a [SignInCopy].
  const SignInCopy({this.title, this.subtitle});

  /// Reads a [SignInCopy] from its JSON form ([toJson]).
  factory SignInCopy.fromJson(Map<String, Object?> json) {
    final title = json.optionalObject('title');
    final subtitle = json.optionalObject('subtitle');
    return SignInCopy(
      title: title == null ? null : LocalizedText.fromJson(title),
      subtitle: subtitle == null ? null : LocalizedText.fromJson(subtitle),
    );
  }

  /// Replaces the default title; `null` keeps it.
  final LocalizedText? title;

  /// Replaces the default subtitle; `null` keeps it.
  final LocalizedText? subtitle;

  /// A copy of this [SignInCopy] with the given fields replaced.
  SignInCopy copyWith({LocalizedText? title, LocalizedText? subtitle}) =>
      SignInCopy(
        title: title ?? this.title,
        subtitle: subtitle ?? this.subtitle,
      );

  /// The JSON form of this [SignInCopy], read back by [SignInCopy.fromJson].
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
