/// The credentials of ONE request to one of the app's APIs, from
/// `LoginFlowAuth.authorizedHeadersFor`.
///
/// Single use: a DPoP proof carries a fresh `jti` and is bound to the method
/// and URL it was built for (RFC 9449 §4.2), so every request — including a
/// retry — asks for a new one. Never persisted, so it has no
/// `toJson`/`fromJson`.
class ResourceAuthorization {
  /// Creates the headers of one request.
  const ResourceAuthorization({required this.authorization, this.dpopProof});

  /// The `Authorization` header value: `DPoP <access token>` for a
  /// DPoP-bound token (RFC 9449 §7.1), `Bearer <access token>` otherwise.
  final String authorization;

  /// The `DPoP` header value (a proof JWT with `htm`, `htu`, `ath` and the
  /// cached server nonce), or `null` when the client does not use DPoP.
  final String? dpopProof;

  /// Both headers, ready to merge into the request.
  Map<String, String> toHeaders() => <String, String>{
    'Authorization': authorization,
    'DPoP': ?dpopProof,
  };

  /// A copy of this [ResourceAuthorization] with the given fields replaced.
  ResourceAuthorization copyWith({String? authorization, String? dpopProof}) =>
      ResourceAuthorization(
        authorization: authorization ?? this.authorization,
        dpopProof: dpopProof ?? this.dpopProof,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ResourceAuthorization &&
          authorization == other.authorization &&
          dpopProof == other.dpopProof;

  @override
  int get hashCode => Object.hash(authorization, dpopProof);

  /// Redacted: the access token and the proof never reach a log.
  @override
  String toString() => 'ResourceAuthorization(isDpop: ${dpopProof != null})';
}
