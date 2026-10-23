import 'dart:async';

import 'package:logger_rs/logger_rs.dart';
import 'package:loginflow_auth/src/core/error/login_flow_error.dart';
import 'package:loginflow_auth/src/core/login_flow_auth.dart';
import 'package:loginflow_auth/src/core/protocol/passkeys/passkey_credential.dart';
import 'package:loginflow_auth/src/core/protocol/step_up/step_up_requirement.dart';
import 'package:loginflow_auth/src/core/session/login_flow_session.dart';
import 'package:loginflow_auth/src/core/state/auth_state.dart';
import 'package:loginflow_auth/src/sign_in/model/field_error.dart';
import 'package:loginflow_auth/src/sign_in/model/passkeys_feedback.dart';
import 'package:loginflow_auth/src/sign_in/model/passkeys_phase.dart';
import 'package:loginflow_auth/src/sign_in/model/passkeys_state.dart';
import 'package:loginflow_auth/src/sign_in/model/sign_in_environment.dart';
import 'package:loginflow_auth/src/sign_in/service/sign_in_service.dart';
import 'package:loginflow_auth/src/sign_in/viewmodel/passkeys_feedback_mapping.dart';
import 'package:loginflow_auth/src/sign_in/viewmodel/sign_in_input_validation.dart';
import 'package:reactive_notifier/reactive_notifier.dart';
import 'package:result_controller/result_controller.dart';

/// Drives the passkey manager of the signed-in user: list, add, rename and
/// delete (`/v1/user/passkeys*`, `doc/server-contract.md` §15). Widgets
/// only render [PasskeysState] and call these methods.
///
/// Adding a passkey goes through the server's recent-authentication gate
/// (RFC 9470). On [StepUpRequired] it does exactly what
/// [LoginFlowAuth.enrollPasskey] documents: [LoginFlowAuth.stepUp] with the
/// server's requirement, then ONE retry once the user has signed in again
/// — never a loop. The sign-in steps of that re-authentication are the
/// bundled sign-in UI's own (`SignInViewModel` follows
/// `LoginFlowAuth.states`).
///
/// Created with no parameters by `PasskeysService.manager`; the client
/// comes from `SignInService.environment`.
class PasskeysViewModel extends ViewModel<PasskeysState> {
  PasskeysViewModel() : super(const PasskeysState(phase: PasskeysLoading()));

  /// Upper bound of one in-flight action, so `isBusy` can never stay set
  /// when an app-supplied passkey adapter never answers. Passkey
  /// ceremonies are bounded first by the adapter itself
  /// (`CorbadoPasskeyAuthenticator.ceremonyTimeout`, 120 s by default);
  /// the step-up may open the browser, bounded by
  /// [LoginFlowAuth.pendingLifetime].
  static final Duration actionTimeout =
      LoginFlowAuth.pendingLifetime + const Duration(minutes: 1);

  SignInEnvironment _environment = const SignInEnvironment.notInstalled();
  StreamSubscription<AuthState>? _authStates;
  bool _isRunning = false;

  /// The signed-in session, kept while a step-up challenge is in progress
  /// (the user is still signed in, `LoginFlowAuth.state` is not `SignedIn`).
  LoginFlowSession? _session;

  /// The enrollment waiting for the re-authentication to finish, the
  /// session it started from — a `SignedIn` with that same session means
  /// the step-up was cancelled, a different one that the user signed in
  /// again — and the list to show meanwhile.
  _PendingEnrollment? _pending;

  @override
  void onDependenciesStateChanged(DependencyState change) {
    change.on<SignInEnvironment>(SignInService.environment, (
      previous,
      current,
    ) {
      if (!change.isSetup && previous != current) {
        _bind(current);
        updateState(_freshState(current));
        unawaited(_load());
      }
    });
  }

  @override
  void init() {
    final environment = SignInService.environment.notifier;
    _bind(environment);
    updateSilently(_freshState(environment));
    unawaited(_load());
  }

  /// Reads the passkeys again after a failure.
  Future<void> retry() async {
    if (_session == null || _isRunning) {
      return;
    }
    updateState(
      data.withoutMessages().copyWith(
        phase: const PasskeysLoading(),
        isBusy: true,
      ),
    );
    await _load();
  }

  /// Enrolls a passkey for the signed-in user — a person or an
  /// access-code subject, `person` or `device`. [username] and
  /// [displayName] are what the platform's passkey sheet shows; without
  /// them they come from the session identity (see [_enrollmentFor]).
  Future<void> addPasskey({String? username, String? displayName}) async {
    final auth = _environment.auth;
    final session = _session;
    final passkeys = _listedPasskeys;
    if (auth == null || session == null || passkeys == null) {
      return;
    }
    final enrollment = _enrollmentFor(
      session,
      username: username,
      displayName: displayName,
    );
    await _run((auth) async {
      final enrolled = await _enroll(auth, enrollment);
      if (enrolled case Err(error: StepUpRequired(:final requirement))) {
        await _stepUp(auth, session, passkeys, enrollment, requirement);
        return;
      }
      _applyEnrolled(enrolled, passkeys);
    });
  }

  /// Abandons the re-authentication of a pending enrollment: back to the
  /// list, nothing enrolled.
  Future<void> cancelReauthentication() async {
    final pending = _pending;
    final auth = _environment.auth;
    if (pending == null || auth == null) {
      return;
    }
    _pending = null;
    updateState(
      data.withoutMessages().copyWith(
        phase: PasskeysListed(passkeys: pending.passkeys),
      ),
    );
    await auth.cancelChallenge();
  }

  /// Why [name] cannot be a passkey's name; [FieldError.none] when it can.
  FieldError passkeyNameError(String name) => name.toRequiredError();

  /// `PATCH /v1/user/passkeys/{id}` with [name] trimmed.
  Future<void> renamePasskey({required String id, required String name}) async {
    final passkeys = _listedPasskeys;
    if (passkeys == null || passkeyNameError(name) != FieldError.none) {
      return;
    }
    await _run((auth) async {
      final renamed = await auth.renamePasskey(id: id, name: name.trim());
      renamed.when(
        ok: (credential) => updateState(
          data.copyWith(
            phase: PasskeysListed(
              passkeys: List<PasskeyCredential>.unmodifiable(
                passkeys.map(
                  (passkey) => passkey.id == id ? credential : passkey,
                ),
              ),
            ),
          ),
        ),
        err: _showError,
      );
    });
  }

  /// `DELETE /v1/user/passkeys/{id}`. The confirmation is the widget's.
  Future<void> deletePasskey(String id) async {
    final passkeys = _listedPasskeys;
    if (passkeys == null) {
      return;
    }
    await _run((auth) async {
      final deleted = await auth.deletePasskey(id);
      deleted.when(
        ok: (_) => updateState(
          data.copyWith(
            phase: PasskeysListed(
              passkeys: List<PasskeyCredential>.unmodifiable(
                passkeys.where((passkey) => passkey.id != id),
              ),
            ),
          ),
        ),
        err: _showError,
      );
    });
  }

  @override
  void dispose() {
    unawaited(_authStates?.cancel());
    super.dispose();
  }

  List<PasskeyCredential>? get _listedPasskeys => switch (data.phase) {
    PasskeysListed(:final passkeys) => passkeys,
    PasskeysNotConfigured() ||
    PasskeysSignedOut() ||
    PasskeysLoading() ||
    PasskeysLoadFailed() ||
    PasskeysReauthenticating() => null,
  };

  PasskeysState _freshState(SignInEnvironment environment) {
    if (environment.auth == null) {
      return const PasskeysState(phase: PasskeysNotConfigured());
    }
    final session = _session;
    if (session == null) {
      return const PasskeysState(phase: PasskeysSignedOut());
    }
    return const PasskeysState(phase: PasskeysLoading(), isBusy: true);
  }

  void _bind(SignInEnvironment environment) {
    _environment = environment;
    _pending = null;
    unawaited(_authStates?.cancel());
    _authStates = null;
    final auth = environment.auth;
    _session = switch (auth?.state) {
      SignedIn(:final session) => session,
      AuthInitializing() ||
      SignedOut() ||
      SsoAvailable() ||
      ChallengeRequired() ||
      AwaitingBrowser() ||
      null => null,
    };
    _authStates = auth?.states.listen(_onAuthStateChanged);
  }

  /// Reads the list for a phase already showing [PasskeysLoading]. Nothing
  /// is updated before the first answer, so [init] may call it.
  Future<void> _load() async {
    final auth = _environment.auth;
    if (auth == null || _session == null || _isRunning) {
      return;
    }
    _isRunning = true;
    await _guarded(() async {
      final listed = await auth.listPasskeys();
      if (isDisposed) {
        return;
      }
      listed.when(
        ok: (passkeys) => updateState(
          data.copyWith(
            phase: PasskeysListed(
              passkeys: List<PasskeyCredential>.unmodifiable(passkeys),
            ),
          ),
        ),
        err: (error) => updateState(
          data.copyWith(
            phase: const PasskeysLoadFailed(),
            feedback: error.toPasskeysFeedback(),
          ),
        ),
      );
    });
  }

  void _onAuthStateChanged(AuthState authState) {
    switch (authState) {
      case SignedIn(:final session):
        final previous = _session;
        _session = session;
        if (!_isRunning) {
          _onSignedIn(session, previous);
        }
      case SignedOut():
        _session = null;
        _pending = null;
        updateState(const PasskeysState(phase: PasskeysSignedOut()));
      case AuthInitializing() ||
          SsoAvailable() ||
          ChallengeRequired() ||
          AwaitingBrowser():
        break;
    }
  }

  void _onSignedIn(LoginFlowSession session, LoginFlowSession? previous) {
    final pending = _pending;
    if (pending != null) {
      _pending = null;
      if (session == pending.session) {
        updateState(
          data.withoutMessages().copyWith(
            phase: PasskeysListed(passkeys: pending.passkeys),
          ),
        );
        return;
      }
      unawaited(_retryEnrollment(pending));
      return;
    }
    final isAnotherUser =
        previous?.identity.subject != session.identity.subject;
    if (isAnotherUser || data.phase is PasskeysSignedOut) {
      updateState(_freshState(_environment));
      unawaited(_load());
    }
  }

  /// [LoginFlowAuth.stepUp] with the server's [requirement]. A step-up the
  /// library completes on its own (a passkey assertion) retries right away;
  /// one that needs the user waits for the sign-in steps
  /// ([PasskeysReauthenticating]).
  Future<void> _stepUp(
    LoginFlowAuth auth,
    LoginFlowSession session,
    List<PasskeyCredential> passkeys,
    _Enrollment enrollment,
    StepUpRequirement requirement,
  ) async {
    final stepped = await auth.stepUp(requirement);
    switch (stepped) {
      case Ok(data: SignedIn()):
        _applyEnrolled(await _enroll(auth, enrollment), passkeys);
      case Ok(data: ChallengeRequired() || AwaitingBrowser()):
        _pending = (
          enrollment: enrollment,
          session: session,
          passkeys: passkeys,
        );
        updateState(
          data.copyWith(phase: PasskeysReauthenticating(passkeys: passkeys)),
        );
      case Ok(data: SignedOut() || AuthInitializing() || SsoAvailable()):
        updateState(const PasskeysState(phase: PasskeysSignedOut()));
      case Err(:final error):
        _showError(error);
    }
  }

  /// The one retry after the user signed in again.
  Future<void> _retryEnrollment(_PendingEnrollment pending) async {
    updateState(
      data.withoutMessages().copyWith(
        phase: PasskeysListed(passkeys: pending.passkeys),
      ),
    );
    await _run(
      (auth) async => _applyEnrolled(
        await _enroll(auth, pending.enrollment),
        pending.passkeys,
      ),
    );
  }

  /// What the platform's passkey sheet shows: [username] and
  /// [displayName] when given, else the session identity. An access-code
  /// subject shows its display name, else the tenant's external subject —
  /// the server's own default (`doc/server-contract.md` §15); a person
  /// shows the email, else the subject. The display name falls back to the
  /// username.
  _Enrollment _enrollmentFor(
    LoginFlowSession session, {
    String? username,
    String? displayName,
  }) {
    final identity = session.identity;
    final resolvedUsername =
        username ??
        switch (identity.externalSubject) {
          final externalSubject? => identity.name ?? externalSubject,
          null => identity.email ?? identity.subject,
        };
    return (
      username: resolvedUsername,
      displayName: displayName ?? identity.name ?? resolvedUsername,
    );
  }

  Future<Result<PasskeyCredential, LoginFlowError>> _enroll(
    LoginFlowAuth auth,
    _Enrollment enrollment,
  ) => auth.enrollPasskey(
    username: enrollment.username,
    displayName: enrollment.displayName,
  );

  void _applyEnrolled(
    Result<PasskeyCredential, LoginFlowError> enrolled,
    List<PasskeyCredential> passkeys,
  ) => enrolled.when(
    ok: (credential) => updateState(
      data.copyWith(
        phase: PasskeysListed(
          passkeys: List<PasskeyCredential>.unmodifiable(<PasskeyCredential>[
            ...passkeys,
            credential,
          ]),
        ),
      ),
    ),
    err: (error) {
      if (error case PasskeyFailed(:final reason, :final code)) {
        Log.w('Passkey enrollment failed: ${reason.name} ($code).');
      }
      updateState(
        data.copyWith(
          phase: PasskeysListed(passkeys: passkeys),
          feedback: error.toPasskeysFeedback(),
        ),
      );
    },
  );

  void _showError(LoginFlowError error) =>
      updateState(data.copyWith(feedback: error.toPasskeysFeedback()));

  /// Runs one user action: busy while it runs, never two at once.
  Future<void> _run(Future<void> Function(LoginFlowAuth auth) action) async {
    final auth = _environment.auth;
    if (auth == null || _isRunning) {
      return;
    }
    _isRunning = true;
    updateState(data.withoutMessages().copyWith(isBusy: true));
    await _guarded(() => action(auth));
  }

  /// Runs [action] and ALWAYS releases the busy state and the in-flight
  /// guard — after an error value, an adapter that threw, or one that never
  /// answered within [actionTimeout] (`LoginFlowAuth` reports expected
  /// failures as values; an app-supplied passkey adapter may still throw or
  /// hang).
  Future<void> _guarded(Future<void> Function() action) async {
    try {
      await action().timeout(actionTimeout);
    } on TimeoutException {
      Log.w(
        'A passkey action did not finish within '
        '${actionTimeout.inMinutes} min.',
      );
      _fail(PasskeysFeedback.unexpected);
    } on Object catch (error, stackTrace) {
      Log.e(
        'A passkey action threw instead of returning an error.',
        error: error,
        stackTrace: stackTrace,
      );
      _fail(PasskeysFeedback.unexpected);
    } finally {
      _isRunning = false;
      if (!isDisposed) {
        updateState(data.copyWith(isBusy: false));
        // A list asked for while another action ran (the client was
        // reinstalled mid-action) is read now, never left loading.
        if (data.phase is PasskeysLoading) {
          unawaited(_load());
        }
      }
    }
  }

  /// [feedback] for an action that never produced a result; a list that
  /// was still loading becomes [PasskeysLoadFailed] so it can be retried.
  void _fail(PasskeysFeedback feedback) {
    if (isDisposed) {
      return;
    }
    updateState(
      data.copyWith(
        phase: data.phase is PasskeysLoading
            ? const PasskeysLoadFailed()
            : null,
        feedback: feedback,
      ),
    );
  }
}

/// The account the platform's passkey sheet shows for a new passkey.
typedef _Enrollment = ({String username, String displayName});

/// An enrollment waiting for the step-up the server asked for: the
/// session before it and the list shown meanwhile.
typedef _PendingEnrollment = ({
  _Enrollment enrollment,
  LoginFlowSession session,
  List<PasskeyCredential> passkeys,
});
