import 'dart:async';

import 'package:http/http.dart' as http;
import 'package:loginflow_auth/src/core/error/login_flow_error.dart';
import 'package:loginflow_auth/src/core/http/transport_reply.dart';
import 'package:result_controller/result_controller.dart';

/// The single place where HTTP exceptions become [LoginFlowError] values.
class LoginFlowTransport {
  const LoginFlowTransport({required this.client, required this.timeout});

  final http.Client client;
  final Duration timeout;

  static const Map<String, String> _acceptJson = <String, String>{
    'Accept': 'application/json',
  };

  Future<Result<TransportReply, LoginFlowError>> getJson(Uri uri) =>
      _send(() => client.get(uri, headers: _acceptJson));

  /// POST `application/x-www-form-urlencoded` (RFC 6749 §3.2,
  /// draft-ietf-oauth-first-party-apps-04 §4.1).
  Future<Result<TransportReply, LoginFlowError>> postForm(
    Uri uri,
    Map<String, String> form, {
    String? bearerToken,
  }) => _send(
    () => client.post(
      uri,
      headers: <String, String>{
        ..._acceptJson,
        'Authorization': ?bearerToken.toBearerHeader(),
      },
      body: form,
    ),
  );

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
