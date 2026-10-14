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
  });

  final int statusCode;
  final String body;

  /// Parsed `Retry-After` header (delta-seconds form only).
  final Duration? retryAfter;

  /// Parsed `max-age` directive of `Cache-Control`.
  final Duration? maxAge;

  bool get isSuccess => statusCode >= 200 && statusCode < 300;

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
  }) => TransportReply(
    statusCode: statusCode ?? this.statusCode,
    body: body ?? this.body,
    retryAfter: retryAfter ?? this.retryAfter,
    maxAge: maxAge ?? this.maxAge,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TransportReply &&
          statusCode == other.statusCode &&
          body == other.body &&
          retryAfter == other.retryAfter &&
          maxAge == other.maxAge;

  @override
  int get hashCode => Object.hash(statusCode, body, retryAfter, maxAge);
}
