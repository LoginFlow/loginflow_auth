// TEST_CHARTER
// Requirement: the access-subject claims (`ext_sub`, `subject_kind`,
// `ext_profile`, `doc/server-contract.md` §16) reach the identity only for an
// access-code subject; a regular user's identity keeps them `null`.
// Oracle: `IdTokenClaims.fromJson` -> `UserIdentity.fromClaims` over raw
// claim sets.
// Risk edge: OpenID Connect Core §5.1 registers `profile` as a profile-page
// URL; the label travels as `ext_profile`, and the standard `profile` claim
// must never be read as it — not even on an access-code subject.
// Layer: pure Dart unit (claim mapping, no I/O).
// Counterfactual: reading `profile` instead of `ext_profile`, or reading
// `ext_profile`/`subject_kind` without requiring `ext_sub`, fails a case.

import 'package:flutter_test/flutter_test.dart';
import 'package:loginflow_auth/loginflow_auth_core.dart';

Map<String, Object?> _claims(Map<String, Object?> extra) => <String, Object?>{
  'iss': 'https://login.example.com',
  'sub': 'subject-1',
  'aud': 'app-one',
  'exp': 2000000000,
  'iat': 1900000000,
  ...extra,
};

void main() {
  test('an access-code subject exposes ext_sub, subject_kind and '
      'ext_profile', () {
    final identity = UserIdentity.fromClaims(
      IdTokenClaims.fromJson(
        _claims(<String, Object?>{
          'ext_sub': 'kiosk:12',
          'subject_kind': 'device',
          'ext_profile': 'Kiosk',
        }),
      ),
    );

    expect(identity.externalSubject, 'kiosk:12');
    expect(identity.subjectKind, AccessSubjectKind.device);
    expect(identity.subjectProfile, 'Kiosk');
    expect(
      UserIdentity.fromJson(identity.toJson()),
      identity,
      reason: 'the stored identity keeps the label under ext_profile',
    );
  });

  test('the standard OIDC profile claim is never read as the label', () {
    final identity = UserIdentity.fromClaims(
      IdTokenClaims.fromJson(
        _claims(<String, Object?>{
          'ext_sub': 'driver:4',
          'subject_kind': 'person',
          'profile': 'https://example.com/driver-4',
        }),
      ),
    );

    expect(identity.externalSubject, 'driver:4');
    expect(identity.subjectProfile, isNull);
  });

  test('a regular user with the standard OIDC profile URL stays a user', () {
    final identity = UserIdentity.fromClaims(
      IdTokenClaims.fromJson(
        _claims(<String, Object?>{
          'email': 'ana@example.com',
          'profile': 'https://example.com/ana',
          'ext_profile': 'Driver',
          'subject_kind': 'person',
        }),
      ),
    );

    expect(identity.externalSubject, isNull);
    expect(identity.subjectKind, isNull);
    expect(identity.subjectProfile, isNull);
  });

  test('an unknown subject_kind is dropped, not a parse failure', () {
    final claims = IdTokenClaims.fromJson(
      _claims(<String, Object?>{'ext_sub': 'robot:1', 'subject_kind': 'robot'}),
    );

    expect(claims.externalSubject, 'robot:1');
    expect(claims.subjectKind, isNull);
  });
}
