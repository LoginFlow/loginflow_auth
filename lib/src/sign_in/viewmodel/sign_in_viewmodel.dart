import 'dart:async';

import 'package:logger_rs/logger_rs.dart';
import 'package:loginflow_auth/src/core/error/login_flow_error.dart';
import 'package:loginflow_auth/src/core/login_flow_auth.dart';
import 'package:loginflow_auth/src/core/protocol/challenge/challenge_step.dart';
import 'package:loginflow_auth/src/core/protocol/login_options/client_login_options.dart';
import 'package:loginflow_auth/src/core/state/auth_state.dart';
import 'package:loginflow_auth/src/core/state/challenge_prompt.dart';
import 'package:loginflow_auth/src/core/state/challenge_purpose.dart';
import 'package:loginflow_auth/src/sign_in/model/auth_method.dart';
import 'package:loginflow_auth/src/sign_in/model/field_error.dart';
import 'package:loginflow_auth/src/sign_in/model/sign_in_environment.dart';
import 'package:loginflow_auth/src/sign_in/model/sign_in_feedback.dart';
import 'package:loginflow_auth/src/sign_in/model/sign_in_phase.dart';
import 'package:loginflow_auth/src/sign_in/model/sign_in_state.dart';
import 'package:loginflow_auth/src/sign_in/service/sign_in_service.dart';
import 'package:loginflow_auth/src/sign_in/viewmodel/sign_in_feedback_mapping.dart';
import 'package:loginflow_auth/src/sign_in/viewmodel/sign_in_input_validation.dart';
import 'package:reactive_notifier/reactive_notifier.dart';
import 'package:result_controller/result_controller.dart';

/// Drives the built-in sign-in UI. All decisions live here: which methods
/// are shown (configured ∩ allowed by the server, in configured order),
/// which screen follows each authentication state, input validation,
/// countdowns. Widgets only render [SignInState] and call these methods.
///
/// Created with no parameters by `SignInService.flow`; the client and
/// configuration come from `SignInService.environment`.
class SignInViewModel extends ViewModel<SignInState> {
  SignInViewModel() : super(const SignInState(phase: SignInLoadingOptions()));

  /// Wait used when a 429 carries no `Retry-After`.
  static const Duration defaultLockout = Duration(seconds: 30);

  SignInEnvironment _environment = const SignInEnvironment.notInstalled();
  StreamSubscription<AuthState>? _authStates;
  Timer? _countdown;
  ClientLoginOptions? _options;
  List<AuthMethod> _available = const <AuthMethod>[];
  AuthState? _lastAuthState;
  bool _isRunning = false;

  /// Methods shown for this client, in configured order.
  List<AuthMethod> get availableMethods => _available;

  @override
  void onDependenciesStateChanged(DependencyState change) {
    change.on<SignInEnvironment>(SignInService.environment, (
      previous,
      current,
    ) {
      if (!change.isSetup && previous != current) {
        updateState(_freshState(current));
        _bind(current);
      }
    });
  }

  @override
  void init() {
    final environment = SignInService.environment.notifier;
    updateSilently(_freshState(environment));
    if (environment.auth != null) {
      _bind(environment);
    }
  }

  /// A new flow for [environment]: nothing from a previous flow survives.
  SignInState _freshState(SignInEnvironment environment) =>
      environment.auth == null
      ? const SignInState(phase: SignInNotConfigured())
      : SignInState(
          phase: const SignInLoadingOptions(),
          copy: environment.configuration.copy,
        );

  /// Reads the server's login options again after a failure.
  Future<void> retryOptions() async {
    updateState(
      data.withoutMessages().copyWith(phase: const SignInLoadingOptions()),
    );
    await _loadOptions();
  }

  void chooseMethod(AuthMethod method) {
    switch (method) {
      case PasswordMethod():
        updateState(_methodState(method, data.withoutMessages()));
      case EmailOtpMethod():
        updateState(_methodState(method, data.withoutMessages()));
      case GoogleMethod():
        unawaited(_run((auth) => auth.signInWithGoogle()));
      case MicrosoftMethod():
        unawaited(_run((auth) => auth.signInWithMicrosoft()));
    }
  }

  Future<void> submitPassword({
    required String email,
    required String password,
  }) async {
    final phase = data.phase;
    if (phase is! SignInPasswordEntry) {
      return;
    }
    final emailError = phase.isIdentifierLocked
        ? FieldError.none
        : email.toEmailError();
    final passwordError = password.isEmpty
        ? FieldError.required
        : FieldError.none;
    if (emailError != FieldError.none || passwordError != FieldError.none) {
      updateState(
        data.withoutMessages().copyWith(
          emailError: emailError,
          passwordError: passwordError,
        ),
      );
      return;
    }
    final loginHint = email.trim();
    updateState(data.copyWith(rememberedEmail: loginHint));
    await _run(
      (auth) => phase.isIdentifierLocked
          ? auth.submitPassword(password)
          : auth.signInWithPassword(loginHint: loginHint, password: password),
    );
  }

  Future<void> requestEmailCode(String email) async {
    final emailError = email.toEmailError();
    if (emailError != FieldError.none) {
      updateState(data.withoutMessages().copyWith(emailError: emailError));
      return;
    }
    final loginHint = email.trim();
    updateState(data.copyWith(rememberedEmail: loginHint));
    await _run((auth) => auth.requestEmailOtp(loginHint: loginHint));
  }

  Future<void> submitEmailCode(String code) async {
    final codeError = code.toRequiredError();
    if (codeError != FieldError.none) {
      updateState(data.withoutMessages().copyWith(codeError: codeError));
      return;
    }
    await _run((auth) => auth.submitEmailOtp(code.trim()));
  }

  Future<void> resendEmailCode() async {
    final phase = data.phase;
    if (phase is! SignInOtpEntry || !phase.canResend) {
      return;
    }
    await _run((auth) => auth.resendEmailOtp());
    final current = data.phase;
    if (current is SignInOtpEntry) {
      updateState(
        data.copyWith(
          phase: current.copyWith(resendSecondsLeft: _resendCooldownSeconds),
        ),
      );
      _startCountdown();
    }
  }

  Future<void> submitSecondFactor(String code) async {
    final phase = data.phase;
    if (phase is! SignInTotpEntry) {
      return;
    }
    final codeError = code.toRequiredError();
    if (codeError != FieldError.none) {
      updateState(data.withoutMessages().copyWith(codeError: codeError));
      return;
    }
    await _run(
      (auth) => phase.isRecoveryCode
          ? auth.submitRecoveryCode(code.trim())
          : auth.submitTotp(code.trim()),
    );
  }

  void toggleRecoveryCode() {
    final phase = data.phase;
    if (phase is SignInTotpEntry && phase.canUseRecoveryCode) {
      updateState(
        data.withoutMessages().copyWith(
          phase: phase.copyWith(isRecoveryCode: !phase.isRecoveryCode),
        ),
      );
    }
  }

  Future<void> continueWithSso() => _run((auth) => auth.continueWithSso());

  Future<void> useAnotherAccount() => _run((auth) => auth.declineSso());

  Future<void> forgotPassword(String email) {
    final loginHint = email.trim();
    return _run(
      (auth) => auth.resetPassword(
        loginHint: loginHint.toEmailError() == FieldError.none
            ? loginHint
            : null,
      ),
    );
  }

  Future<void> signUp() => _run((auth) => auth.signUp());

  /// Back to the method picker; abandons a server challenge in progress.
  Future<void> goBack() async {
    final auth = _environment.auth;
    if (auth?.state is ChallengeRequired) {
      await _run((auth) => auth.cancelChallenge());
      return;
    }
    updateState(_entryState(data.withoutMessages()));
  }

  @override
  void dispose() {
    _stopCountdown();
    unawaited(_authStates?.cancel());
    super.dispose();
  }

  void _bind(SignInEnvironment environment) {
    _environment = environment;
    _stopCountdown();
    unawaited(_authStates?.cancel());
    _authStates = null;
    _options = null;
    final auth = environment.auth;
    if (auth == null) {
      return;
    }
    _authStates = auth.states.listen(_onAuthStateChanged);
    unawaited(_loadOptions());
  }

  Future<void> _loadOptions() async {
    final auth = _environment.auth;
    if (auth == null) {
      return;
    }
    final options = await auth.fetchLoginOptions();
    if (isDisposed) {
      return;
    }
    options.when(
      ok: (options) {
        _options = options;
        _available = _allowedMethods(options);
        _lastAuthState = auth.state;
        final configuration = _environment.configuration;
        _apply(
          auth.state,
          data.copyWith(
            copy: configuration.copy,
            isSignUpOffered:
                configuration.isSelfSignUpOffered &&
                options.isSelfSignUpEnabled,
          ),
        );
      },
      err: (error) {
        Log.w('Login options unavailable: ${error.message}');
        updateState(
          data.copyWith(
            phase: const SignInOptionsUnavailable(),
            feedback: error.toFeedback(),
          ),
        );
      },
    );
  }

  /// Configured methods the server allows, first occurrence of each kind.
  List<AuthMethod> _allowedMethods(ClientLoginOptions options) {
    final seen = <String>{};
    return List<AuthMethod>.unmodifiable(
      _environment.configuration.methods.where(
        (method) =>
            options.allows(method.wireName) && seen.add(method.wireName),
      ),
    );
  }

  void _onAuthStateChanged(AuthState authState) {
    if (_isRunning || _options == null || authState == _lastAuthState) {
      return;
    }
    _lastAuthState = authState;
    _apply(authState, data.withoutMessages());
  }

  Future<void> _run(
    Future<Result<AuthState, LoginFlowError>> Function(LoginFlowAuth auth)
    action,
  ) async {
    final auth = _environment.auth;
    if (auth == null || _isRunning) {
      return;
    }
    _isRunning = true;
    updateState(data.withoutMessages().copyWith(isBusy: true));
    final result = await action(auth);
    _isRunning = false;
    if (isDisposed) {
      return;
    }
    _lastAuthState = auth.state;
    final base = data.copyWith(isBusy: false);
    result.when(
      ok: (authState) => _apply(authState, base),
      err: (error) => _applyError(error, auth.state, base),
    );
  }

  void _applyError(
    LoginFlowError error,
    AuthState authState,
    SignInState base,
  ) {
    if (error case RateLimited(:final retryAfter)) {
      updateState(
        base.copyWith(
          phase: SignInLockedOut(
            secondsLeft: (retryAfter ?? defaultLockout).inSeconds,
          ),
          canGoBack: false,
        ),
      );
      _startCountdown();
      return;
    }
    final next = base.phase is SignInAwaitingBrowser
        ? _nextState(authState, base)
        : base;
    updateState(next.copyWith(feedback: error.toFeedback()));
  }

  void _apply(AuthState authState, SignInState base) {
    final wasOtpEntry = data.phase is SignInOtpEntry;
    final next = _nextState(authState, base);
    updateState(next);
    switch (next.phase) {
      case SignInOtpEntry() when !wasOtpEntry:
        _startCountdown();
      case SignInOtpEntry() || SignInLockedOut():
        break;
      case SignInNotConfigured() ||
          SignInLoadingOptions() ||
          SignInOptionsUnavailable() ||
          SignInNoMethods() ||
          SignInChoosingMethod() ||
          SignInPasswordEntry() ||
          SignInEmailEntry() ||
          SignInTotpEntry() ||
          SignInAwaitingBrowser() ||
          SignInSsoConfirm() ||
          SignInCompleted():
        _stopCountdown();
    }
  }

  SignInState _nextState(
    AuthState authState,
    SignInState base,
  ) => switch (authState) {
    AuthInitializing() => base.copyWith(phase: const SignInLoadingOptions()),
    SignedOut(:final reason, :final loginHint) => _entryState(
      base.copyWith(
        feedback: base.feedback == SignInFeedback.none
            ? reason.toFeedback()
            : base.feedback,
        rememberedEmail: loginHint,
      ),
    ),
    SsoAvailable(:final candidate) => base.copyWith(
      phase: SignInSsoConfirm(candidate: candidate),
      canGoBack: false,
    ),
    ChallengeRequired(:final prompt, :final purpose) => _challengeState(
      prompt,
      purpose,
      base,
    ),
    AwaitingBrowser() => base.copyWith(phase: const SignInAwaitingBrowser()),
    SignedIn(:final session) => base.copyWith(
      phase: SignInCompleted(session: session),
      canGoBack: false,
    ),
  };

  SignInState _challengeState(
    ChallengePrompt prompt,
    ChallengePurpose purpose,
    SignInState base,
  ) {
    final withFeedback = base.copyWith(
      feedback: prompt.stepError.toFeedback(),
      canGoBack: true,
    );
    final current = data.phase;
    return switch (prompt.step) {
      ChallengeStep.password => withFeedback.copyWith(
        phase: SignInPasswordEntry(
          isForgotPasswordShown: _isForgotPasswordShown,
          isIdentifierLocked: purpose != ChallengePurpose.signIn,
        ),
        canGoBack: _available.length > 1 || purpose != ChallengePurpose.signIn,
      ),
      ChallengeStep.emailOtp => withFeedback.copyWith(
        phase: SignInOtpEntry(
          email: prompt.loginHint ?? base.rememberedEmail,
          resendSecondsLeft: current is SignInOtpEntry
              ? current.resendSecondsLeft
              : _resendCooldownSeconds,
        ),
      ),
      ChallengeStep.totp => withFeedback.copyWith(
        phase: SignInTotpEntry(
          isRecoveryCode: false,
          canUseRecoveryCode: prompt.alternatives.contains(
            ChallengeStep.recoveryCode,
          ),
        ),
      ),
      ChallengeStep.recoveryCode => withFeedback.copyWith(
        phase: const SignInTotpEntry(
          isRecoveryCode: true,
          canUseRecoveryCode: true,
        ),
      ),
      ChallengeStep.selectMethod => withFeedback.copyWith(
        phase: SignInChoosingMethod(methods: _available),
        canGoBack: false,
      ),
      ChallengeStep.upstreamToken => base,
    };
  }

  /// The first screen: the picker, or the only method directly.
  SignInState _entryState(SignInState base) {
    final methods = _available;
    if (methods.isEmpty) {
      return base.copyWith(phase: const SignInNoMethods(), canGoBack: false);
    }
    if (methods.length == 1) {
      return _methodState(methods.single, base);
    }
    return base.copyWith(
      phase: SignInChoosingMethod(methods: methods),
      canGoBack: false,
    );
  }

  SignInState _methodState(AuthMethod method, SignInState base) {
    final canGoBack = _available.length > 1;
    return switch (method) {
      PasswordMethod() => base.copyWith(
        phase: SignInPasswordEntry(
          isForgotPasswordShown:
              method.isForgotPasswordShown &&
              (_options?.isPasswordResetEnabled ?? false),
        ),
        canGoBack: canGoBack,
      ),
      EmailOtpMethod() => base.copyWith(
        phase: const SignInEmailEntry(),
        canGoBack: canGoBack,
      ),
      GoogleMethod() || MicrosoftMethod() => base.copyWith(
        phase: SignInChoosingMethod(methods: <AuthMethod>[method]),
        canGoBack: false,
      ),
    };
  }

  bool get _isForgotPasswordShown =>
      (_options?.isPasswordResetEnabled ?? false) &&
      _available.whereType<PasswordMethod>().any(
        (method) => method.isForgotPasswordShown,
      );

  int get _resendCooldownSeconds =>
      (_available.whereType<EmailOtpMethod>().firstOrNull ??
              const EmailOtpMethod())
          .resendCooldown
          .inSeconds;

  /// Ticks once a second while the current phase has seconds left; never
  /// leaves a timer running for a phase that has nothing to count.
  void _startCountdown() {
    _countdown?.cancel();
    _countdown = null;
    final hasSecondsLeft = switch (data.phase) {
      SignInOtpEntry(:final resendSecondsLeft) => resendSecondsLeft > 0,
      SignInLockedOut(:final secondsLeft) => secondsLeft > 0,
      SignInNotConfigured() ||
      SignInLoadingOptions() ||
      SignInOptionsUnavailable() ||
      SignInNoMethods() ||
      SignInChoosingMethod() ||
      SignInPasswordEntry() ||
      SignInEmailEntry() ||
      SignInTotpEntry() ||
      SignInAwaitingBrowser() ||
      SignInSsoConfirm() ||
      SignInCompleted() => false,
    };
    if (hasSecondsLeft) {
      _countdown = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
    }
  }

  void _stopCountdown() {
    _countdown?.cancel();
    _countdown = null;
  }

  void _tick() {
    final phase = data.phase;
    if (phase case SignInOtpEntry(:final resendSecondsLeft)
        when resendSecondsLeft > 0) {
      updateState(
        data.copyWith(
          phase: phase.copyWith(resendSecondsLeft: resendSecondsLeft - 1),
        ),
      );
      if (resendSecondsLeft == 1) {
        _stopCountdown();
      }
      return;
    }
    if (phase case SignInLockedOut(:final secondsLeft) when secondsLeft > 1) {
      updateState(
        data.copyWith(phase: phase.copyWith(secondsLeft: secondsLeft - 1)),
      );
      return;
    }
    _stopCountdown();
    final auth = _environment.auth;
    if (phase is SignInLockedOut && auth != null) {
      _apply(auth.state, data.withoutMessages());
    }
  }
}
