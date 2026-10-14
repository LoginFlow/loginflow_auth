/// Why a redirect back from the authorization endpoint was refused.
enum AuthorizationResponseProblem {
  /// No authorization request was pending when the callback arrived.
  noPendingRequest,

  /// `state` differs from the one sent (RFC 6749 §10.12, RFC 9700 §2.1).
  stateMismatch,

  /// `iss` is missing or differs from the issuer (RFC 9207 §2.4).
  issuerMismatch,

  /// The callback carries neither `code` nor `error`.
  missingCode,

  /// The pending request is older than its lifetime (`doc/decisions.md` D17).
  requestExpired,
}
