import 'dart:convert';

import 'package:loginflow_auth/src/core/crypto/base64_url_encoding.dart';
import 'package:loginflow_auth/src/core/crypto/secure_random_source.dart';
import 'package:loginflow_auth/src/core/crypto/sha256_hashing.dart';
import 'package:loginflow_auth/src/core/json/json_field_reader.dart';

/// A PKCE `code_verifier` and its `S256` `code_challenge` (RFC 7636).
///
/// Only `S256` exists here: `plain` is prohibited by RFC 9700 §2.1.1 and
/// draft-ietf-oauth-v2-1 §4.1.1.
class PkcePair {
  const PkcePair({required this.codeVerifier, required this.codeChallenge});

  /// A fresh pair: 32 random bytes base64url-encoded give a 43-character
  /// verifier with 256 bits of entropy (RFC 7636 §4.1, §7.1).
  factory PkcePair.generate(SecureRandomSource randomSource) {
    final verifier = randomSource.nextBytes(32).toBase64UrlNoPadding();
    return PkcePair(
      codeVerifier: verifier,
      codeChallenge: PkcePair.challengeFor(verifier),
    );
  }

  factory PkcePair.fromJson(Map<String, Object?> json) => PkcePair(
    codeVerifier: json.requireString('code_verifier'),
    codeChallenge: json.requireString('code_challenge'),
  );

  /// The value sent as `code_challenge_method`.
  static const String method = 'S256';

  final String codeVerifier;
  final String codeChallenge;

  /// `BASE64URL(SHA256(ASCII(code_verifier)))` (RFC 7636 §4.2).
  static String challengeFor(String codeVerifier) =>
      ascii.encode(codeVerifier).toSha256().toBase64UrlNoPadding();

  /// Whether [challenge] is the S256 transformation of [codeVerifier], i.e.
  /// what the authorization server checks at the token endpoint
  /// (RFC 7636 §4.6).
  bool isVerifiedBy(String challenge) =>
      challengeFor(codeVerifier) == challenge;

  PkcePair copyWith({String? codeVerifier, String? codeChallenge}) => PkcePair(
    codeVerifier: codeVerifier ?? this.codeVerifier,
    codeChallenge: codeChallenge ?? this.codeChallenge,
  );

  Map<String, Object?> toJson() => <String, Object?>{
    'code_verifier': codeVerifier,
    'code_challenge': codeChallenge,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PkcePair &&
          codeVerifier == other.codeVerifier &&
          codeChallenge == other.codeChallenge;

  @override
  int get hashCode => Object.hash(codeVerifier, codeChallenge);

  /// Never prints the verifier.
  @override
  String toString() => 'PkcePair(codeChallenge: $codeChallenge)';
}
