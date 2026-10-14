/// Comparisons between a received navigation and a registered redirect URI.
extension CallbackUriMatching on Uri {
  /// Same scheme, host, port and path as [redirectUri] (the query is the
  /// response). Redirect URIs are compared exactly (RFC 9700 §4.1.3).
  bool targets(Uri redirectUri) =>
      scheme == redirectUri.scheme &&
      host == redirectUri.host &&
      port == redirectUri.port &&
      path == redirectUri.path;

  /// This URI without query and fragment, for cleaning the address bar.
  Uri withoutResponseParameters() => Uri(
    scheme: scheme,
    userInfo: userInfo.isEmpty ? null : userInfo,
    host: host,
    port: hasPort ? port : null,
    path: path,
  );
}
