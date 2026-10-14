import 'dart:convert';

import 'package:loginflow_auth/src/core/crypto/base64_url_encoding.dart';
import 'package:loginflow_auth/src/core/error/id_token_failure.dart';
import 'package:loginflow_auth/src/core/error/login_flow_error.dart';
import 'package:loginflow_auth/src/core/jose/jws_header.dart';
import 'package:result_controller/result_controller.dart';

/// A JWS in compact serialization (RFC 7515 §7.1), split but not verified.
///
/// A parsing intermediate that only lives inside the validator, so it has no
/// `toJson`/`fromJson`.
class CompactJws {
  const CompactJws({
    required this.header,
    required this.payloadJson,
    required this.signingInput,
    required this.signature,
  });

  final JwsHeader header;

  /// The decoded payload, verified to be a JSON object.
  final String payloadJson;

  /// `BASE64URL(header) || '.' || BASE64URL(payload)`.
  final String signingInput;

  /// The signature, base64url.
  final String signature;

  /// Splits and decodes [token]; any structural problem is `malformed`.
  static Result<CompactJws, LoginFlowError> parse(String token) {
    const malformed = IdTokenRejected(reason: IdTokenFailure.malformed);
    final parts = token.split('.');
    if (parts.length != 3 || parts.any((part) => part.isEmpty)) {
      return Err(malformed);
    }
    final headerBytes = parts[0].tryDecodeBase64Url();
    final payloadBytes = parts[1].tryDecodeBase64Url();
    if (headerBytes == null ||
        payloadBytes == null ||
        parts[2].tryDecodeBase64Url() == null) {
      return Err(malformed);
    }
    try {
      final header = jsonDecode(utf8.decode(headerBytes));
      final payload = utf8.decode(payloadBytes);
      if (header is! Map<String, Object?> ||
          jsonDecode(payload) is! Map<String, Object?>) {
        return Err(malformed);
      }
      return Ok(
        CompactJws(
          header: JwsHeader.fromJson(header),
          payloadJson: payload,
          signingInput: '${parts[0]}.${parts[1]}',
          signature: parts[2],
        ),
      );
    } on FormatException {
      return Err(malformed);
    }
  }

  /// The payload as a JSON object (checked by [parse]).
  Map<String, Object?> get claims =>
      jsonDecode(payloadJson) as Map<String, Object?>;

  CompactJws copyWith({
    JwsHeader? header,
    String? payloadJson,
    String? signingInput,
    String? signature,
  }) => CompactJws(
    header: header ?? this.header,
    payloadJson: payloadJson ?? this.payloadJson,
    signingInput: signingInput ?? this.signingInput,
    signature: signature ?? this.signature,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CompactJws &&
          header == other.header &&
          payloadJson == other.payloadJson &&
          signingInput == other.signingInput &&
          signature == other.signature;

  @override
  int get hashCode => Object.hash(header, payloadJson, signingInput, signature);
}
