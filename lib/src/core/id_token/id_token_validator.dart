import 'package:logger_rs/logger_rs.dart';
import 'package:loginflow_auth/src/core/config/login_flow_clock.dart';
import 'package:loginflow_auth/src/core/discovery/discovery_document.dart';
import 'package:loginflow_auth/src/core/error/id_token_failure.dart';
import 'package:loginflow_auth/src/core/error/login_flow_error.dart';
import 'package:loginflow_auth/src/core/id_token/id_token_claims.dart';
import 'package:loginflow_auth/src/core/id_token/id_token_expectations.dart';
import 'package:loginflow_auth/src/core/jose/compact_jws.dart';
import 'package:loginflow_auth/src/core/jose/jwks_cache.dart';
import 'package:loginflow_auth/src/core/jose/jws_signature_verifier.dart';
import 'package:result_controller/result_controller.dart';

/// Validates ID tokens before any claim is trusted
/// (OpenID Connect Core §3.1.3.7 and §12.2, RFC 8725).
class IdTokenValidator {
  const IdTokenValidator({
    required this.jwks,
    required this.clock,
    required this.clockSkew,
    this.verifier = const JwsSignatureVerifier(),
  });

  /// Algorithms this library implements. The effective set is the
  /// intersection with the issuer's `id_token_signing_alg_values_supported`.
  static const List<String> implementedAlgorithms = <String>['RS256', 'ES256'];

  final JwksCache jwks;
  final LoginFlowClock clock;
  final Duration clockSkew;
  final JwsSignatureVerifier verifier;

  Future<Result<IdTokenClaims, LoginFlowError>> validate(
    String idToken, {
    required DiscoveryDocument discovery,
    required IdTokenExpectations expectations,
  }) async {
    final parsed = CompactJws.parse(idToken);
    if (parsed case Err(:final error)) {
      return Err(error);
    }
    final jws = parsed.data;
    final headerFailure = _headerFailure(jws, discovery);
    if (headerFailure != null) {
      return _reject(headerFailure);
    }
    final IdTokenClaims claims;
    try {
      claims = IdTokenClaims.fromJson(jws.claims);
    } on FormatException {
      return _reject(IdTokenFailure.malformed);
    }
    final key = await jwks.keyFor(
      jwksUri: discovery.jwksUri,
      keyId: jws.header.keyId ?? '',
      algorithm: jws.header.algorithm,
    );
    return key.flatMap((key) {
      if (!verifier.verify(jws, key)) {
        return _reject(IdTokenFailure.invalidSignature);
      }
      final claimFailure = _claimFailure(claims, discovery, expectations);
      return claimFailure == null ? Ok(claims) : _reject(claimFailure);
    });
  }

  IdTokenFailure? _headerFailure(CompactJws jws, DiscoveryDocument discovery) {
    final header = jws.header;
    final isAllowed =
        implementedAlgorithms.contains(header.algorithm) &&
        discovery.idTokenSigningAlgorithms.contains(header.algorithm);
    if (!isAllowed) {
      return IdTokenFailure.unsupportedAlgorithm;
    }
    if (header.keyId == null) {
      return IdTokenFailure.unknownKey;
    }
    if (header.critical.isNotEmpty) {
      return IdTokenFailure.criticalHeader;
    }
    final type = header.type?.toLowerCase();
    if (type != null && type != 'jwt') {
      return IdTokenFailure.wrongTokenType;
    }
    return null;
  }

  IdTokenFailure? _claimFailure(
    IdTokenClaims claims,
    DiscoveryDocument discovery,
    IdTokenExpectations expectations,
  ) {
    final now = clock.now();
    final audience = expectations.audience;
    final expectedNonce = expectations.nonce;
    final expectedSubject = expectations.subject;
    if (claims.issuer != discovery.issuer) {
      return IdTokenFailure.issuerMismatch;
    }
    if (audience != null && !claims.audiences.contains(audience)) {
      return IdTokenFailure.audienceMismatch;
    }
    if (audience != null &&
        (claims.audiences.length > 1 || claims.authorizedParty != null) &&
        claims.authorizedParty != audience) {
      return IdTokenFailure.authorizedPartyMismatch;
    }
    if (!expectations.allowExpired &&
        !now.isBefore(claims.expiresAt.add(clockSkew))) {
      return IdTokenFailure.expired;
    }
    if (claims.issuedAt.isAfter(now.add(clockSkew))) {
      return IdTokenFailure.issuedInFuture;
    }
    if (expectedNonce != null && claims.nonce != expectedNonce) {
      return IdTokenFailure.nonceMismatch;
    }
    if (expectedSubject != null && claims.subject != expectedSubject) {
      return IdTokenFailure.subjectMismatch;
    }
    return null;
  }

  Result<IdTokenClaims, LoginFlowError> _reject(IdTokenFailure failure) {
    Log.w('ID token rejected: ${failure.name}');
    return Err(IdTokenRejected(reason: failure));
  }
}
