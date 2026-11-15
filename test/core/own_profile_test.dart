// Core test (tdd-light) of the own profile (`/v1/app/profile`,
// `doc/server-contract.md` §24, API 0.26.0).
// Requirement: the signed-in person reads their email (none for a
// passkey-only account) and names, and sets their names; the session's
// identity then carries the new name; a refused name is a typed error.
// Oracle: the fake server's real dispatch (`own_profile_handler.rs` shapes,
// the DPoP-bound LoginFlow token required), the request it received and the
// public `SignedIn` identity.

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:loginflow_auth/loginflow_auth_core.dart';

import '../support/auth_fixture.dart';
import '../support/fake_login_flow_server.dart';
import '../support/fake_passkey_authenticator.dart';
import '../support/test_signing_keys.dart';

void main() {
  late TestSigningKeys keys;
  late FakeLoginFlowServer server;

  setUpAll(() => keys = TestSigningKeys.generate());

  setUp(() async {
    server = await FakeLoginFlowServer.start(keys)
      ..requiresDpop = true
      ..loginMethods = <String>['passkey', 'passkey_signup'];
  });

  tearDown(() => server.close());

  /// A passkey-only account, signed up as "Ana": no email, no last name.
  Future<AuthFixture> anaSignedUp() async {
    final fixture = AuthFixture.create(
      server,
      passkey: FakePasskeyAuthenticator(),
      enableDpop: true,
    );
    await fixture.auth.initialize();
    final signedUp = await fixture.auth.signUpWithPasskey(displayName: 'Ana');
    expect(signedUp.data, isA<SignedIn>());
    return fixture;
  }

  test('a passkey-only account reads a profile without an email', () async {
    final fixture = await anaSignedUp();

    final profile = await fixture.auth.fetchProfile();

    expect(profile.data, const OwnProfile(firstName: 'Ana', name: 'Ana'));
    expect(profile.data.email, isNull);
    final request = server.ownProfileRequests.single;
    expect(request.method, 'GET');
    expect(request.headers['authorization'], startsWith('DPoP '));
  });

  test('setting a name sends only that name, answers the profile after the '
      'change and the session identity follows', () async {
    final fixture = await anaSignedUp();

    final updated = await fixture.auth.updateProfile(lastName: 'Ruiz');

    expect(
      updated.data,
      const OwnProfile(firstName: 'Ana', lastName: 'Ruiz', name: 'Ana Ruiz'),
    );
    final request = server.ownProfileRequests.single;
    expect(request.method, 'PATCH');
    expect(jsonDecode(request.body), <String, Object?>{'last_name': 'Ruiz'});
    final identity = (fixture.auth.state as SignedIn).session.identity;
    expect(identity.name, 'Ana Ruiz');
    expect(identity.email, isNull);
  });

  test('a refused name is InvalidProfileName and changes nothing', () async {
    final fixture = await anaSignedUp();

    final updated = await fixture.auth.updateProfile(firstName: 'Ana 2');

    expect(updated.errorOrNull, const InvalidProfileName());
    expect((await fixture.auth.fetchProfile()).data.name, 'Ana');
    expect((fixture.auth.state as SignedIn).session.identity.name, 'Ana');
  });
}
