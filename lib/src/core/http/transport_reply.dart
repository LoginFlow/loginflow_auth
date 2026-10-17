import 'dart:convert';

import 'package:loginflow_auth/src/core/error/login_flow_error.dart';
import 'package:result_controller/result_controller.dart';

/// The parts of an HTTP response the protocol clients look at.
///
/// Built once at the HTTP boundary and never persisted, so it has no
/// `toJson`/`fromJson`.
class TransportReply {
  const TransportReply({
    required this.statusCode,
    required this.body,
    this.retryAfter,
    this.maxAge,
    this.dpopNonce,
    this.wwwAuthenticate,
  });

  final int statusCode;
  final String body;

  /// Parsed `Retry-After` header (delta-seconds form only).
  final Duration? retryAfter;

  /// Parsed `max-age` directive of `Cache-Control`.
  final Duration? maxAge;

  /// The `DPoP-Nonce` response header (RFC 9449 §8), when the server sent
  /// one: either a fresh nonce for the next proof, or (on a 400
  /// `use_dpop_nonce`) the nonce this request must be retried with.
  final String? dpopNonce;

  /// The `WWW-Authenticate` response header, when present.
  final String? wwwAuthenticate;

  bool get isSuccess => statusCode >= 200 && statusCode < 300;

  /// Whether the server asked for this request to be retried with the nonce in
  /// [dpopNonce] (RFC 9449 §8 and §9): a `400` whose error is `use_dpop_nonce`
  /// on the authorization server, or a `401` whose `WWW-Authenticate` carries
  /// `error="use_dpop_nonce"` on a resource. Any other error is never retried,
  /// even when a `DPoP-Nonce` header comes with it.
  bool get requiresDpopNonceRetry {
    if (dpopNonce == null) {
      return false;
    }
    return switch (statusCode) {
      400 => _errorCode() == 'use_dpop_nonce',
      401 => wwwAuthenticate?.contains('error="use_dpop_nonce"') ?? false,
      _ => false,
    };
  }

  String? _errorCode() {
    final parsed = jsonObject();
    if (parsed case Err()) {
      return null;
    }
    final code = parsed.data['error'];
    return code is String ? code : null;
  }

  /// The body as a JSON object, or a typed error when it is not one.
  Result<Map<String, Object?>, LoginFlowError> jsonObject() {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, Object?>) {
        return Ok(decoded);
      }
      return Err(
        ServerResponseInvalid(
          statusCode: statusCode,
          description: 'The body is not a JSON object.',
        ),
      );
    } on FormatException {
      return Err(
        ServerResponseInvalid(
          statusCode: statusCode,
          description: 'The body is not valid JSON.',
        ),
      );
    }
  }

  TransportReply copyWith({
    int? statusCode,
    String? body,
    Duration? retryAfter,
    Duration? maxAge,
    String? dpopNonce,
    String? wwwAuthenticate,
  }) => TransportReply(
    statusCode: statusCode ?? this.statusCode,
    body: body ?? this.body,
    retryAfter: retryAfter ?? this.retryAfter,
    maxAge: maxAge ?? this.maxAge,
    dpopNonce: dpopNonce ?? this.dpopNonce,
    wwwAuthenticate: wwwAuthenticate ?? this.wwwAuthenticate,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TransportReply &&
          statusCode == other.statusCode &&
          body == other.body &&
          retryAfter == other.retryAfter &&
          maxAge == other.maxAge &&
          dpopNonce == other.dpopNonce &&
          wwwAuthenticate == other.wwwAuthenticate;

  @override
  int get hashCode => Object.hash(
    statusCode,
    body,
    retryAfter,
    maxAge,
    dpopNonce,
    wwwAuthenticate,
  );
}
