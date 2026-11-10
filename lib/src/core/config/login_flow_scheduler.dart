import 'dart:async';

/// Runs work later: the polling of a phone approval or a sign-in QR
/// (`LoginFlowAuth.requestPhoneApproval`, `LoginFlowAuth.requestQrSignIn`).
/// Tests replace it to fire each poll on demand instead of waiting.
abstract interface class LoginFlowScheduler {
  /// Runs [task] once after [delay]. Calling the returned function before
  /// then cancels it; afterwards it does nothing.
  void Function() schedule(Duration delay, void Function() task);
}

/// [LoginFlowScheduler] on a [Timer].
final class TimerLoginFlowScheduler implements LoginFlowScheduler {
  /// Creates a [TimerLoginFlowScheduler].
  const TimerLoginFlowScheduler();

  @override
  void Function() schedule(Duration delay, void Function() task) =>
      Timer(delay, task).cancel;
}
