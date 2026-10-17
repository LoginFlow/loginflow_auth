import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:logger_rs/logger_rs.dart';
import 'package:loginflow_auth/src/core/dpop/dpop_proof_factory.dart';
import 'package:loginflow_auth/src/core/error/login_flow_error.dart';
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

  /// The last `DPoP-Nonce` this authorization server sent, reused as the
  /// `nonce` claim of the next proof (RFC 9449 §8). One transport per
  /// [LoginFlowAuth] instance, so this is per-app state, not global.
  String? _nonce;

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
  }) async {
    final proofFactory = dpop;
    if (proofFactory == null) {
      return _send(
        () => client.post(
          uri,
          headers: <String, String>{
            ..._acceptJson,
            'Authorization': ?bearerToken.toBearerHeader(),
          },
          body: form,
        ),
      );
    }
    final first = await _postFormWithProof(
      proofFactory,
      uri,
      form,
      bearerToken: bearerToken,
      nonce: _nonce,
    );
    return first.flatMapAsync((reply) async {
      if (reply.dpopNonce != null) {
        _nonce = reply.dpopNonce;
      }
      if (reply.requiresDpopNonceRetry) {
        return _postFormWithProof(
          proofFactory,
          uri,
          form,
          bearerToken: bearerToken,
          nonce: reply.dpopNonce,
        );
      }
      return Ok(reply);
    });
  }

  Future<Result<TransportReply, LoginFlowError>> _postFormWithProof(
    DpopProofFactory proofFactory,
    Uri uri,
    Map<String, String> form, {
    required String? bearerToken,
    required String? nonce,
  }) async {
    final proofResult = await proofFactory.buildProof(
      httpMethod: 'POST',
      httpUri: uri,
      nonce: nonce,
      accessToken: bearerToken,
    );
    if (proofResult case Err(:final error)) {
      Log.e('Building the DPoP proof failed: ${error.message}');
      return Err(error);
    }
    return _send(
      () => client.post(
        uri,
        headers: <String, String>{
          ..._acceptJson,
          'DPoP': proofResult.data,
          'Authorization': ?bearerToken.toDpopHeader(),
        },
        body: form,
      ),
    );
  }

  /// Same proof-and-nonce-retry shape as [postForm], generalized to any
  /// method/body for the JSON account API (RFC 9449 §7.1, §8 apply to
  /// resource endpoints exactly like the token and challenge endpoints).
  Future<Result<TransportReply, LoginFlowError>> _sendJson({
    required String httpMethod,
    required Uri uri,
    required String bearerToken,
    Map<String, Object?>? jsonBody,
  }) async {
    final body = jsonBody == null ? null : jsonEncode(jsonBody);
    final proofFactory = dpop;
    if (proofFactory == null) {
      return _send(
        () => _rawRequest(
          httpMethod,
          uri,
          body: body,
          headers: <String, String>{
            ..._acceptJson,
            if (body != null) 'Content-Type': 'application/json',
            'Authorization': ?bearerToken.toBearerHeader(),
          },
        ),
      );
    }
    final first = await _sendJsonWithProof(
      proofFactory,
      httpMethod,
      uri,
      body: body,
      bearerToken: bearerToken,
      nonce: _nonce,
    );
    return first.flatMapAsync((reply) async {
      if (reply.dpopNonce != null) {
        _nonce = reply.dpopNonce;
      }
      if (reply.requiresDpopNonceRetry) {
        return _sendJsonWithProof(
          proofFactory,
          httpMethod,
          uri,
          body: body,
          bearerToken: bearerToken,
          nonce: reply.dpopNonce,
        );
      }
      return Ok(reply);
    });
  }

  Future<Result<TransportReply, LoginFlowError>> _sendJsonWithProof(
    DpopProofFactory proofFactory,
    String httpMethod,
    Uri uri, {
    required String? body,
    required String bearerToken,
    required String? nonce,
  }) async {
    final proofResult = await proofFactory.buildProof(
      httpMethod: httpMethod,
      httpUri: uri,
      nonce: nonce,
      accessToken: bearerToken,
    );
    if (proofResult case Err(:final error)) {
      Log.e('Building the DPoP proof failed: ${error.message}');
      return Err(error);
    }
    return _send(
      () => _rawRequest(
        httpMethod,
        uri,
        body: body,
        headers: <String, String>{
          ..._acceptJson,
          if (body != null) 'Content-Type': 'application/json',
          'DPoP': proofResult.data,
          'Authorization': ?bearerToken.toDpopHeader(),
        },
      ),
    );
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
