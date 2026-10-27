import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:loginflow_auth/loginflow_auth_core.dart';

import '../support/auth_fixture.dart';
import '../support/fake_login_flow_server.dart';
import '../support/test_signing_keys.dart';

const String _luz = 'luz@example.com';
const String _luzPassword = 'Luz-Password-1';
const String _newPassword = 'N3w-Passw0rd!';

/// The in-app password change (`POST /v1/user/change-password`) against a
/// fake LoginFlow that answers like `auth_handler.rs::change_password`: the
/// session's own DPoP-bound token, the recent sign-in the credential needs,
/// and `422 VALIDATION_ERROR` for a refused password. No browser, ever.
void main() {
  late TestSigningKeys keys;
  late FakeLoginFlowServer server;

  setUpAll(() => keys = TestSigningKeys.generate());

  setUp(() async {
    server = await FakeLoginFlowServer.start(keys);
    server.requiresDpop = true;
    // An account with no second factor: no TOTP, no passkey.
    server.users[_luz] = const FakeUser(
      subject: 'cu_luz',
      email: _luz,
      password: _luzPassword,
      name: 'Luz Mar',
    );
  });

  tearDown(() => server.close());

  Future<AuthFixture> signedIn({required String password}) async {
    final fixture = AuthFixture.create(server, enableDpop: true);
    await fixture.auth.initialize();
    final result = await fixture.auth.signInWithPassword(
      loginHint: _luz,
      password: password,
    );
    expect(result.data, isA<SignedIn>());
    return fixture;
  }

  // TEST_CHARTER
  // Requirement: a recently signed-in person changes their password in the
  // app, with no browser, and the new one signs them in.
  // Oracle: the public `Result`, the wire (method, path, body, `DPoP`
  // authorization and proof), the browser never opened, and a new sign-in
  // with the new password.
  // Risk edge: the wrong path or body field (`400`), a Bearer token the
  // DPoP-bound session refuses, a browser hand-off.
  // Layer: integration against the fake LoginFlow (real HTTP, real DPoP).
  // Counterfactual: sending `password` instead of `new_password`, or another
  // path, makes the call fail and the new password not sign in.
  test('a recent sign-in changes the password in the app, with DPoP and no '
      'browser', () async {
    final fixture = await signedIn(password: _luzPassword);

    final changed = await fixture.auth.changePassword(_newPassword);

    expect(changed.isOk, isTrue, reason: '$changed');
    final request = server.changePasswordRequests.single;
    expect(request.method, 'POST');
    expect(request.uri.path, '/v1/user/change-password');
    expect(jsonDecode(request.body), <String, Object?>{
      'new_password': _newPassword,
    });
    expect(request.headers['authorization'], startsWith('DPoP '));
    expect(request.headers['dpop'], isNotNull);
    expect(fixture.browser.openedUrls, isEmpty);
    await signedIn(password: _newPassword);
  });

  // TEST_CHARTER
  // Requirement: past the 300 s recent-auth window the change answers
  // `StepUpRequired` with the server's `max_age`, so the app steps up and
  // asks again; nothing changes on the server.
  // Oracle: the public `Result`, and the old password still signing in.
  // Risk edge: the challenge lives only in `WWW-Authenticate`; the body is
  // the generic `UNAUTHORIZED` envelope.
  // Layer: integration against the fake LoginFlow.
  // Counterfactual: the first test asks with a recent sign-in and succeeds.
  test('a stale sign-in -> StepUpRequired, the password unchanged', () async {
    final fixture = await signedIn(password: _luzPassword);
    server.expireRecentAuthentications();

    final changed = await fixture.auth.changePassword(_newPassword);

    expect(
      changed.errorOrNull,
      const StepUpRequired(
        requirement: StepUpRequirement(maxAge: Duration(seconds: 300)),
      ),
    );
    await signedIn(password: _luzPassword);
  });

  // TEST_CHARTER
  // Requirement: a weak password, or the current one, is a typed refusal
  // carrying the server's reason.
  // Oracle: the public `Result` of each call.
  // Risk edge: `422 VALIDATION_ERROR` read as `ServerResponseInvalid` with
  // the generic "Some fields are invalid." message.
  // Layer: integration against the fake LoginFlow.
  // Counterfactual: mapping `422` with `toAccountApiError` turns both into
  // `ServerResponseInvalid`.
  test('a weak or unchanged password -> PasswordRejected with the server '
      'reason', () async {
    final fixture = await signedIn(password: _luzPassword);

    final weak = await fixture.auth.changePassword('short');
    final same = await fixture.auth.changePassword(_luzPassword);

    expect(
      weak.errorOrNull,
      const PasswordRejected(reason: FakeLoginFlowServer.weakPasswordDetails),
    );
    expect(
      same.errorOrNull,
      const PasswordRejected(reason: FakeLoginFlowServer.samePasswordDetails),
    );
  });
}
