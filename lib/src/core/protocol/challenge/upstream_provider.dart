/// Federated identity providers reachable through the challenge flow.
enum UpstreamProvider {
  google('google'),
  microsoft('microsoft'),
  apple('apple'),
  facebook('facebook');

  const UpstreamProvider(this.wireName);

  final String wireName;

  static UpstreamProvider? fromWireName(String value) {
    for (final provider in values) {
      if (provider.wireName == value) {
        return provider;
      }
    }
    return null;
  }
}
