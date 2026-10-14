import 'package:loginflow_auth/src/core/json/json_field_reader.dart';
import 'package:loginflow_auth/src/core/json/list_equality.dart';

/// Where the publisher's apps share the Native SSO entry on this device.
///
/// See the README "Native SSO" section for the entitlement and manifest
/// changes each app needs.
class NativeSsoOptions {
  const NativeSsoOptions({
    this.appleAccessGroup,
    this.androidSiblingAuthorities = const <String>[],
  });

  factory NativeSsoOptions.fromJson(Map<String, Object?> json) =>
      NativeSsoOptions(
        appleAccessGroup: json.optionalString('apple_access_group'),
        androidSiblingAuthorities: json.stringList(
          'android_sibling_authorities',
        ),
      );

  /// iOS/macOS Keychain access group with the Team ID prefix, e.g.
  /// `ABCDE12345.com.acme.loginflow.sso` (APPLE-KC-SHARE).
  final String? appleAccessGroup;

  /// Content provider authorities of the sibling apps, e.g.
  /// `com.acme.orders.loginflow.sso`. Each must be declared in `<queries>`.
  final List<String> androidSiblingAuthorities;

  NativeSsoOptions copyWith({
    String? appleAccessGroup,
    List<String>? androidSiblingAuthorities,
  }) => NativeSsoOptions(
    appleAccessGroup: appleAccessGroup ?? this.appleAccessGroup,
    androidSiblingAuthorities:
        androidSiblingAuthorities ?? this.androidSiblingAuthorities,
  );

  Map<String, Object?> toJson() => <String, Object?>{
    'apple_access_group': ?appleAccessGroup,
    'android_sibling_authorities': androidSiblingAuthorities,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is NativeSsoOptions &&
          appleAccessGroup == other.appleAccessGroup &&
          androidSiblingAuthorities.hasSameValues(
            other.androidSiblingAuthorities,
          );

  @override
  int get hashCode =>
      Object.hash(appleAccessGroup, androidSiblingAuthorities.valuesHash);
}
