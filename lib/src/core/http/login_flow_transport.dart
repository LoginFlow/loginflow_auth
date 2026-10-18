import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:logger_rs/logger_rs.dart';
import 'package:loginflow_auth/src/core/dpop/dpop_proof_factory.dart';
import 'package:loginflow_auth/src/core/error/login_flow_error.dart';
import 'package:loginflow_auth/src/core/http/resource_authorization.dart';
import 'package:loginflow_auth/src/core/http/transport_reply.dart';
import 'package:result_controller/result_controller.dart';

/// The single place where HTTP exceptions become [LoginFlowError] values,
/// and (when [dpop] is configured) where every request carries a DPoP proof
/// (RFC 9449) instead of a bare Bearer token.
class LoginFlowTransport {
  LoginFlowTransport({required this.client, required this.timeout, this.dpop});

  final http.Client client;
  final Duration timeout;

  /// `null` for a client the server does not require DPoP from
  /// (`doc/server-contract.md` §13: only `native` + `first_party` clients).
  final DpopProofFactory? dpop;

  /// The last `DPoP-Nonce` each server sent, keyed by origin, reused as the
  /// `nonce` claim of the next proof to that server (RFC 9449 §8: a nonce is
  /// issued by, and only valid for, one authorization or resource server).
  /// One transport per [LoginFlowAuth] instance, so this is per-app state,
  /// not global.
  final Map<String, String> _nonces = <String, String>{};

  static const Map<String, String> _acceptJson = <String, String>{
    'Accept': 'application/json',
  };

  Future<Result<TransportReply, LoginFlowError>> getJson(
    Uri uri, {
    String? bearerToken,
  }) {
    if (bearerToken == null) {
      return _send(() => client.get(uri, headers: _acceptJson));
    }
    return _sendJson(httpMethod: 'GET', uri: uri, bearerToken: bearerToken);
  }

  /// POST `application/json`, for LoginFlow's account-management REST API
  /// (e.g. `/v1/user/passkeys/*`): fixed paths, not resolved from discovery
  /// (`doc/server-contract.md` covers only the OAuth/OIDC endpoint set).
  Future<Result<TransportReply, LoginFlowError>> postJson(
    Uri uri,
    Map<String, Object?> body, {
    required String bearerToken,
  }) => _sendJson(
    httpMethod: 'POST',
    uri: uri,
    bearerToken: bearerToken,
    jsonBody: body,
  );

  Future<Result<TransportReply, LoginFlowError>> patchJson(
    Uri uri,
    Map<String, Object?> body, {
    required String bearerToken,
  }) => _sendJson(
    httpMethod: 'PATCH',
    uri: uri,
    bearerToken: bearerToken,
    jsonBody: body,
  );

  Future<Result<TransportReply, LoginFlowError>> deleteJson(
    Uri uri, {
    required String bearerToken,
  }) => _sendJson(httpMethod: 'DELETE', uri: uri, bearerToken: bearerToken);

  /// POST `application/x-www-form-urlencoded` (RFC 6749 §3.2,
  /// draft-ietf-oauth-first-party-apps-04 §4.1). With [dpop] configured, a
  /// proof is attached to every call (token endpoint, challenge endpoint,
  /// resource endpoints alike) and [bearerToken], when given, is sent as
  /// `Authorization: DPoP <token>` with a matching `ath` claim instead of
  /// `Bearer` (RFC 9449 §7.1). A `DPoP-Nonce` on the response is retried
  /// once with that nonce (RFC 9449 §8).
  Future<Result<TransportReply, LoginFlowError>> postForm(
    Uri uri,
    Map<String, String> form, {
    String? bearerToken,
  }) => _sendAuthorized(
    httpMethod: 'POST',
    uri: uri,
    accessToken: bearerToken,
    send: (headers) => client.post(
      uri,
      headers: <String, String>{..._acceptJson, ...headers},
      body: form,
    ),
  );

  /// The `Authorization` and `DPoP` headers for one request to [uri] with
  /// [accessToken], using the nonce last cached for that server. The same
  /// headers every request of this transport carries, exposed for the app's
  /// own resource servers (`LoginFlowAuth.authorizeResourceRequest`).
  Future<Result<ResourceAuthorization, LoginFlowError>> authorize({
    required String httpMethod,
    required Uri uri,
    required String accessToken,
  }) async {
    final proofResult = await _proof(
      httpMethod: httpMethod,
      uri: uri,
      accessToken: accessToken,
      nonce: _nonces[uri.nonceScope],
    );
    return proofResult.map(
      (proof) => ResourceAuthorization(
        authorization: proof == null
            ? 'Bearer $accessToken'
            : 'DPoP $accessToken',
        dpopProof: proof,
      ),
    );
  }

  /// Caches the `DPoP-Nonce` of [reply] for [uri]'s server and tells whether
  /// the request must be sent once more with it: a `400 use_dpop_nonce`
  /// from an authorization server or a `401` whose `WWW-Authenticate`
  /// carries `error="use_dpop_nonce"` from a resource (RFC 9449 §8, §9).
  /// Always `false` without DPoP.
  bool acceptReply(Uri uri, TransportReply reply) {
    if (dpop == null) {
      return false;
    }
    final nonce = reply.dpopNonce;
    if (nonce != null) {
      _nonces[uri.nonceScope] = nonce;
    }
    return reply.requiresDpopNonceRetry;
  }

  /// Same proof-and-nonce-retry shape as [postForm], generalized to any
  /// method/body for the JSON account API (RFC 9449 §7.1, §8 apply to
  /// resource endpoints exactly like the token and challenge endpoints).
  Future<Result<TransportReply, LoginFlowError>> _sendJson({
    required String httpMethod,
    required Uri uri,
    required String bearerToken,
    Map<String, Object?>? jsonBody,
  }) {
    final body = jsonBody == null ? null : jsonEncode(jsonBody);
    return _sendAuthorized(
      httpMethod: httpMethod,
      uri: uri,
      accessToken: bearerToken,
      send: (headers) => _rawRequest(
        httpMethod,
        uri,
        body: body,
        headers: <String, String>{
          ..._acceptJson,
          if (body != null) 'Content-Type': 'application/json',
          ...headers,
        },
      ),
    );
  }

  /// Sends with the authorization headers of [_proof] and, when the server
  /// asks for a nonce, once more with a fresh proof carrying it.
  Future<Result<TransportReply, LoginFlowError>> _sendAuthorized({
    required String httpMethod,
    required Uri uri,
    required String? accessToken,
    required Future<http.Response> Function(Map<String, String> headers) send,
  }) async {
    final first = await _sendWithProof(
      httpMethod: httpMethod,
      uri: uri,
      accessToken: accessToken,
      send: send,
    );
    return first.flatMapAsync(
      (reply) async => acceptReply(uri, reply)
          ? _sendWithProof(
              httpMethod: httpMethod,
              uri: uri,
              accessToken: accessToken,
              send: send,
            )
          : Ok(reply),
    );
  }

  Future<Result<TransportReply, LoginFlowError>> _sendWithProof({
    required String httpMethod,
    required Uri uri,
    required String? accessToken,
    required Future<http.Response> Function(Map<String, String> headers) send,
  }) async {
    final proofResult = await _proof(
      httpMethod: httpMethod,
      uri: uri,
      accessToken: accessToken,
      nonce: _nonces[uri.nonceScope],
    );
    if (proofResult case Err(:final error)) {
      return Err(error);
    }
    final proof = proofResult.data;
    return _send(
      () => send(<String, String>{
        'DPoP': ?proof,
        'Authorization': ?(proof == null
            ? accessToken.toBearerHeader()
            : accessToken.toDpopHeader()),
      }),
    );
  }

  /// The DPoP proof for one request, or `null` for a client without DPoP.
  /// [accessToken], when given, becomes the `ath` claim.
  Future<Result<String?, LoginFlowError>> _proof({
    required String httpMethod,
    required Uri uri,
    required String? accessToken,
    required String? nonce,
  }) async {
    final proofFactory = dpop;
    if (proofFactory == null) {
      return Ok(null);
    }
    final proofResult = await proofFactory.buildProof(
      httpMethod: httpMethod,
      httpUri: uri,
      nonce: nonce,
      accessToken: accessToken,
    );
    if (proofResult case Err(:final error)) {
      Log.e('Building the DPoP proof failed: ${error.message}');
      return Err(error);
    }
    return Ok(proofResult.data);
  }

  Future<http.Response> _rawRequest(
    String method,
    Uri uri, {
    required Map<String, String> headers,
    String? body,
  }) async {
    final request = http.Request(method, uri)..headers.addAll(headers);
    if (body != null) {
      request.body = body;
    }
    final streamed = await client.send(request);
    return http.Response.fromStream(streamed);
  }

  Future<Result<TransportReply, LoginFlowError>> _send(
    Future<http.Response> Function() request,
  ) async {
    try {
      final response = await request().timeout(timeout);
      return Ok(
        TransportReply(
          statusCode: response.statusCode,
          body: response.body,
          retryAfter: response.headers['retry-after']?.toRetryAfter(),
          maxAge: response.headers['cache-control']?.toMaxAge(),
          dpopNonce: response.headers['dpop-nonce'],
          wwwAuthenticate: response.headers['www-authenticate'],
        ),
      );
    } on http.ClientException catch (error) {
      return Err(NetworkFailure(description: error.message));
    } on TimeoutException {
      return Err(
        NetworkFailure(
          description: 'No response within ${timeout.inSeconds}s.',
        ),
      );
    }
  }
}

extension on String? {
  String? toBearerHeader() {
    final token = this;
    return token == null ? null : 'Bearer $token';
  }

  String? toDpopHeader() {
    final token = this;
    return token == null ? null : 'DPoP $token';
  }
}

extension<T> on Result<T, LoginFlowError> {
  /// `Result.flatMap`'s async counterpart: this package's `flatMap` only
  /// accepts a synchronous transform.
  Future<Result<T, LoginFlowError>> flatMapAsync(
    Future<Result<T, LoginFlowError>> Function(T value) transform,
  ) => when(ok: transform, err: (error) async => Err(error));
}

extension on Uri {
  /// The server a DPoP nonce belongs to (RFC 6454 origin).
  String get nonceScope => '$scheme://$host:$port';
}

extension on String {
  Duration? toRetryAfter() {
    final seconds = int.tryParse(trim());
    return seconds == null ? null : Duration(seconds: seconds);
  }

  Duration? toMaxAge() {
    for (final directive in split(',')) {
      final parts = directive.trim().split('=');
      if (parts.length == 2 && parts.first.toLowerCase() == 'max-age') {
        final seconds = int.tryParse(parts.last);
        return seconds == null ? null : Duration(seconds: seconds);
      }
    }
    return null;
  }
}
