import 'dart:async';

import 'package:loginflow_auth/loginflow_auth_core.dart';

/// A [LoginFlowScheduler] the test drives: every task waits until [runNext]
/// fires it, and [delays] records what the library asked for.
class ManualScheduler implements LoginFlowScheduler {
  final List<Duration> delays = <Duration>[];
  final List<_ScheduledTask> _tasks = <_ScheduledTask>[];
  final StreamController<Duration> _scheduled =
      StreamController<Duration>.broadcast();

  /// The tasks scheduled and neither run nor cancelled.
  int get pendingCount => _tasks.where((task) => !task.isCancelled).length;

  /// Completes when the library schedules its next task.
  Future<Duration> get nextScheduled => _scheduled.stream.first;

  @override
  void Function() schedule(Duration delay, void Function() task) {
    final scheduled = _ScheduledTask(task);
    delays.add(delay);
    _tasks.add(scheduled);
    _scheduled.add(delay);
    return () => scheduled.isCancelled = true;
  }

  /// Runs the oldest task still scheduled; `false` when there is none.
  bool runNext() {
    while (_tasks.isNotEmpty) {
      final task = _tasks.removeAt(0);
      if (!task.isCancelled) {
        task.run();
        return true;
      }
    }
    return false;
  }
}

class _ScheduledTask {
  _ScheduledTask(this.run);

  final void Function() run;
  bool isCancelled = false;
}
