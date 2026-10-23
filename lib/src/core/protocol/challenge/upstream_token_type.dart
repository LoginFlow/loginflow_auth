/// What `upstream_token` carries, sent to the server as
/// `upstream_token_type` (`doc/server-contract.md` §5.4).
enum UpstreamTokenType {
  /// An OIDC ID token (Apple's `identityToken`; Google always; Facebook
  /// iOS Limited Login).
  idToken('id_token'),

  /// A provider access token (Facebook Android classic login).
  accessToken('access_token');

  const UpstreamTokenType(this.wireName);

  /// The name of this value on the wire.
  final String wireName;

  /// The value whose [wireName] is the given name, or `null` for an unknown one.
  static UpstreamTokenType? fromWireName(String value) {
    for (final type in values) {
      if (type.wireName == value) {
        return type;
      }
    }
    return null;
  }
}
