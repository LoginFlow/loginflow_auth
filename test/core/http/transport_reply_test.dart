import 'package:flutter_test/flutter_test.dart';
import 'package:loginflow_auth/src/core/http/transport_reply.dart';

void main() {
  group('TransportReply.requiresDpopNonceRetry (RFC 9449 §8, §9)', () {
    test('a 400 use_dpop_nonce with a DPoP-Nonce asks for one retry', () {
      const reply = TransportReply(
        statusCode: 400,
        body: '{"error":"use_dpop_nonce"}',
        dpopNonce: 'n-1',
      );

      expect(reply.requiresDpopNonceRetry, isTrue);
    });

    test('a 401 with WWW-Authenticate use_dpop_nonce asks for one retry', () {
      const reply = TransportReply(
        statusCode: 401,
        body: '',
        dpopNonce: 'n-1',
        wwwAuthenticate: 'DPoP error="use_dpop_nonce"',
      );

      expect(reply.requiresDpopNonceRetry, isTrue);
    });

    test('any other error is never retried, even with a DPoP-Nonce header', () {
      const invalidGrant = TransportReply(
        statusCode: 400,
        body: '{"error":"invalid_grant"}',
        dpopNonce: 'n-1',
      );
      const invalidProof = TransportReply(
        statusCode: 401,
        body: '',
        dpopNonce: 'n-1',
        wwwAuthenticate: 'DPoP error="invalid_dpop_proof"',
      );

      expect(invalidGrant.requiresDpopNonceRetry, isFalse);
      expect(invalidProof.requiresDpopNonceRetry, isFalse);
    });
  });
}
