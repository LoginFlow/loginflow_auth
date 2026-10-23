/// Time source for token expiry and ID token validation.
abstract interface class LoginFlowClock {
  /// The current time, in UTC.
  DateTime now();
}

/// [LoginFlowClock] that reads the system clock in UTC.
final class SystemLoginFlowClock implements LoginFlowClock {
  /// Creates a [SystemLoginFlowClock].
  const SystemLoginFlowClock();

  @override
  DateTime now() => DateTime.now().toUtc();
}
