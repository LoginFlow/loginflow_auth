/// Time source for token expiry and ID token validation.
abstract interface class LoginFlowClock {
  DateTime now();
}

/// [LoginFlowClock] that reads the system clock in UTC.
final class SystemLoginFlowClock implements LoginFlowClock {
  const SystemLoginFlowClock();

  @override
  DateTime now() => DateTime.now().toUtc();
}
