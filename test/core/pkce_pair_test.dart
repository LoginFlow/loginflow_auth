import 'package:flutter_test/flutter_test.dart';
import 'package:loginflow_auth/loginflow_auth_core.dart';

void main() {
  group('PkcePair', () {
    test('S256 matches the RFC 7636 Appendix B test vector', () {
      const verifier = 'dBjftJeZ4CVP-mB92K27uhbUJU1p1r_wW1gFWFOEjXk';

      expect(
        PkcePair.challengeFor(verifier),
        'E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM',
      );
    });

    test('a generated verifier has 43 unreserved characters (32 bytes)', () {
      final pair = PkcePair.generate(const PlatformSecureRandomSource());

      expect(pair.codeVerifier, hasLength(43));
      expect(pair.codeVerifier, matches(RegExp(r'^[A-Za-z0-9\-._~]{43}$')));
      expect(pair.codeChallenge, PkcePair.challengeFor(pair.codeVerifier));
    });

    test('verification accepts its own challenge and rejects another', () {
      final pair = PkcePair.generate(const PlatformSecureRandomSource());
      final other = PkcePair.generate(const PlatformSecureRandomSource());

      expect(pair.isVerifiedBy(pair.codeChallenge), isTrue);
      expect(pair.isVerifiedBy(other.codeChallenge), isFalse);
      expect(pair.codeVerifier, isNot(other.codeVerifier));
    });

    test('round-trips through JSON without exposing the verifier in text', () {
      final pair = PkcePair.generate(const PlatformSecureRandomSource());

      expect(PkcePair.fromJson(pair.toJson()), pair);
      expect(pair.toString(), isNot(contains(pair.codeVerifier)));
    });
  });
}
