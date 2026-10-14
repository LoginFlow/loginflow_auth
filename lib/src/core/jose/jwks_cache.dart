import 'package:loginflow_auth/src/core/config/login_flow_clock.dart';
import 'package:loginflow_auth/src/core/error/id_token_failure.dart';
import 'package:loginflow_auth/src/core/error/login_flow_error.dart';
import 'package:loginflow_auth/src/core/http/login_flow_transport.dart';
import 'package:loginflow_auth/src/core/http/oauth_error_body.dart';
import 'package:loginflow_auth/src/core/jose/json_web_key.dart';
import 'package:loginflow_auth/src/core/jose/json_web_key_set.dart';
import 'package:result_controller/result_controller.dart';

/// Caches the issuer JWKS by `kid` and refetches on an unknown `kid`.
///
/// Mirrors the validator guidance in OpenID Connect Core §10.1.1 and the
/// key-rollover advice of `doc/decisions.md` D7: honour the
/// response cache lifetime, refetch when a token names a key that is not
/// cached, and rate-limit those forced refetches.
class JwksCache {
  JwksCache({required this.transport, required this.clock});

  /// Lifetime when the JWKS response has no `Cache-Control: max-age`.
  static const Duration defaultLifetime = Duration(hours: 6);

  /// Minimum spacing between refetches triggered by an unknown `kid`.
  static const Duration forcedRefreshInterval = Duration(minutes: 1);

  final LoginFlowTransport transport;
  final LoginFlowClock clock;

  JsonWebKeySet? _keys;
  Uri? _source;
  DateTime? _expiresAt;
  DateTime? _lastFetchAt;
  Future<Result<JsonWebKeySet, LoginFlowError>>? _inFlight;

  Future<Result<JsonWebKey, LoginFlowError>> keyFor({
    required Uri jwksUri,
    required String keyId,
    required String algorithm,
  }) async {
    final now = clock.now();
    final cached = _source == jwksUri ? _keys : null;
    final expiresAt = _expiresAt;
    final isFresh = expiresAt != null && now.isBefore(expiresAt);
    final cachedKey = cached?.keyFor(keyId: keyId, algorithm: algorithm);
    if (cachedKey != null && isFresh) {
      return Ok(cachedKey);
    }
    final lastFetch = _lastFetchAt;
    final mayRefetch =
        cached == null ||
        !isFresh ||
        lastFetch == null ||
        now.difference(lastFetch) >= forcedRefreshInterval;
    if (!mayRefetch) {
      return Err(const IdTokenRejected(reason: IdTokenFailure.unknownKey));
    }
    final fetched = await (_inFlight ?? _startFetch(jwksUri));
    return fetched.flatMap((keys) {
      final key = keys.keyFor(keyId: keyId, algorithm: algorithm);
      return key == null
          ? Err(const IdTokenRejected(reason: IdTokenFailure.unknownKey))
          : Ok(key);
    });
  }

  /// One JWKS download at a time: concurrent validations share it.
  Future<Result<JsonWebKeySet, LoginFlowError>> _startFetch(Uri jwksUri) {
    late final Future<Result<JsonWebKeySet, LoginFlowError>> fetch;
    fetch = _fetch(jwksUri).whenComplete(() {
      if (identical(_inFlight, fetch)) {
        _inFlight = null;
      }
    });
    _inFlight = fetch;
    return fetch;
  }

  Future<Result<JsonWebKeySet, LoginFlowError>> _fetch(Uri jwksUri) async {
    final reply = await transport.getJson(jwksUri);
    return reply.flatMap((reply) {
      if (!reply.isSuccess) {
        return Err(reply.toLoginFlowError());
      }
      return reply.jsonObject().flatMap((json) {
        try {
          final keys = JsonWebKeySet.fromJson(json);
          final now = clock.now();
          _keys = keys;
          _source = jwksUri;
          _lastFetchAt = now;
          _expiresAt = now.add(reply.maxAge ?? defaultLifetime);
          return Ok(keys);
        } on FormatException catch (error) {
          return Err(
            ServerResponseInvalid(
              statusCode: reply.statusCode,
              description: error.message,
            ),
          );
        }
      });
    });
  }
}
