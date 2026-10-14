import 'dart:math';

import 'package:loginflow_auth/src/core/crypto/base64_url_encoding.dart';

/// Source of cryptographically secure random bytes.
abstract interface class SecureRandomSource {
  List<int> nextBytes(int length);
}

/// [SecureRandomSource] backed by the platform CSPRNG ([Random.secure]).
final class PlatformSecureRandomSource implements SecureRandomSource {
  const PlatformSecureRandomSource();

  @override
  List<int> nextBytes(int length) {
    final random = Random.secure();
    return List<int>.generate(length, (_) => random.nextInt(256));
  }
}

/// Opaque random strings for `state`, `nonce` and similar one-time values.
extension RandomTokens on SecureRandomSource {
  /// 32 random bytes, base64url: 256 bits of entropy (RFC 9700 §4.7.1,
  /// draft-ietf-oauth-first-party-apps-04 §9.6.2).
  String nextOpaqueToken() => nextBytes(32).toBase64UrlNoPadding();
}
