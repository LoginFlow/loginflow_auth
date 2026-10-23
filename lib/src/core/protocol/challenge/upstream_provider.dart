/// Federated identity providers reachable through the challenge flow.
enum UpstreamProvider {
  /// Google: natively with `loginflow_auth_google`, or in the browser.
  google('google'),

  /// Microsoft: always in the browser.
  microsoft('microsoft'),

  /// Apple: natively on iOS/macOS with `loginflow_auth_apple`, or in the browser.
  apple('apple'),

  /// Facebook: natively with `loginflow_auth_facebook`, or in the browser.
  facebook('facebook');

  const UpstreamProvider(this.wireName);

  /// The name of this value on the wire.
  final String wireName;

  /// The value whose [wireName] is the given name, or `null` for an unknown one.
  static UpstreamProvider? fromWireName(String value) {
    for (final provider in values) {
      if (provider.wireName == value) {
        return provider;
      }
    }
    return null;
  }
}
