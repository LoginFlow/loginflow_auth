/// Why an ID token was rejected (OpenID Connect Core §3.1.3.7, RFC 8725).
enum IdTokenFailure {
  /// Not a compact JWS with three base64url parts and JSON header/claims.
  malformed,

  /// `alg` is not RS256/ES256, is not advertised by discovery, or is `none`.
  unsupportedAlgorithm,

  /// No key in the issuer's JWKS matches the token `kid` and algorithm.
  unknownKey,

  /// The signature does not verify with the issuer key.
  invalidSignature,

  /// The header carries a `crit` parameter this library does not understand.
  criticalHeader,

  /// The header `typ` marks the token as something other than an ID token.
  wrongTokenType,

  /// `iss` is not exactly the configured issuer.
  issuerMismatch,

  /// `aud` does not contain this client's `client_id`.
  audienceMismatch,

  /// `aud` has several values and `azp` is absent or not this client.
  authorizedPartyMismatch,

  /// `exp` is in the past (beyond the allowed clock skew).
  expired,

  /// `iat` is in the future (beyond the allowed clock skew).
  issuedInFuture,

  /// `nonce` is missing or differs from the value sent in the request.
  nonceMismatch,

  /// `sub` differs from the subject of the current session.
  subjectMismatch,
}
