/// Transport rules for every endpoint the library talks to.
extension EndpointSecurity on Uri {
  /// `https`, or plain `http` only on a loopback host (local development and
  /// tests). RFC 6749 §3.1/§3.2 require TLS for these endpoints.
  bool get isSecureOrLoopback =>
      scheme == 'https' ||
      (scheme == 'http' &&
          (host == '127.0.0.1' || host == 'localhost' || host == '::1'));

  /// An issuer identifier: `https` (or loopback), no query, no fragment
  /// (OpenID Connect Discovery §3, RFC 8414 §2).
  bool get isValidIssuer => isSecureOrLoopback && !hasQuery && !hasFragment;

  /// A redirect URI this client may register: no fragment or userinfo
  /// (RFC 6749 §3.1.2, RFC 9700 §2.1); `https`, loopback `http` (RFC 8252
  /// §7.3, RFC 9700 §2.6), or a reverse-domain private-use scheme
  /// (RFC 8252 §7.1, §8.4).
  bool get isValidRedirect {
    if (hasFragment || userInfo.isNotEmpty || !hasScheme) {
      return false;
    }
    return switch (scheme) {
      'https' => host.isNotEmpty,
      'http' => isSecureOrLoopback,
      _ => scheme.contains('.'),
    };
  }
}
