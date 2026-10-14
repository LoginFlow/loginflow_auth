import 'package:loginflow_auth/loginflow_auth_core.dart';

/// A clock the test moves forward to expire access tokens.
class TestClock implements LoginFlowClock {
  TestClock() : _now = DateTime.now().toUtc();

  DateTime _now;

  void advance(Duration duration) => _now = _now.add(duration);

  @override
  DateTime now() => _now;
}
