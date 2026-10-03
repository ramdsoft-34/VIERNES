import 'package:viernes/features/alerts/domain/alert_scheduler.dart';
import 'package:viernes/features/alerts/domain/planned_alert.dart';

/// Programador en memoria: refleja qué avisos quedarían en el sistema.
class FakeAlertScheduler implements AlertScheduler {
  final Map<int, (PlannedAlert, AlertContent)> scheduled = {};

  List<PlannedAlert> alertsFor(String reminderId) =>
      scheduled.values
          .map((entry) => entry.$1)
          .where((a) => a.reminderId == reminderId)
          .toList()
        ..sort((a, b) => a.at.compareTo(b.at));

  @override
  Future<void> schedule(PlannedAlert alert, AlertContent content) async =>
      scheduled[alert.notificationId] = (alert, content);

  @override
  Future<void> cancel(Iterable<int> notificationIds) async =>
      notificationIds.forEach(scheduled.remove);

  @override
  Future<void> cancelAll() async => scheduled.clear();
}
