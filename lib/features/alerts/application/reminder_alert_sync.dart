import 'package:viernes/core/logging/app_logger.dart';
import 'package:viernes/core/utils/clock.dart';
import 'package:viernes/features/alerts/domain/alert_planner.dart';
import 'package:viernes/features/alerts/domain/alert_scheduler.dart';
import 'package:viernes/features/alerts/domain/notification_ids.dart';
import 'package:viernes/features/alerts/domain/planned_alert.dart';
import 'package:viernes/features/reminders/domain/entities/reminder.dart';
import 'package:viernes/features/reminders/presentation/reminder_formatters.dart';
import 'package:viernes/features/settings/domain/app_settings.dart';
import 'package:viernes/l10n/gen/app_localizations.dart';

/// Mantiene los avisos del sistema alineados con los recordatorios.
class ReminderAlertSync {
  ReminderAlertSync({
    required this._scheduler,
    required this._settings,
    required this._clock,
    required this._l10n,
  });

  final AlertScheduler _scheduler;
  final AppSettings Function() _settings;
  final Clock _clock;
  final AppLocalizations _l10n;

  /// Android limita las alarmas por app (~500); se programan solo los
  /// recordatorios más próximos y el resto al volver a abrir la app.
  static const maxScheduledReminders = 60;

  /// Reprograma los avisos de un recordatorio (o los quita si ya no aplica).
  Future<void> sync(Reminder reminder) async {
    await _scheduler.cancel(NotificationIds.allFor(reminder.id));
    await _scheduleAll(reminder);
  }

  Future<void> remove(String reminderId) =>
      _scheduler.cancel(NotificationIds.allFor(reminderId));

  /// Rehace todo el plan (al abrir la app o al cambiar los ajustes).
  Future<void> syncAll(Iterable<Reminder> reminders) async {
    await _scheduler.cancelAll();
    final active = reminders.where((r) => r.isActive).toList()
      ..sort((a, b) => a.nextTriggerAt.compareTo(b.nextTriggerAt));
    for (final reminder in active.take(maxScheduledReminders)) {
      await _scheduleAll(reminder);
    }
    AppLogger.info('Avisos reprogramados: ${active.length}', tag: 'alertas');
  }

  Future<void> _scheduleAll(Reminder reminder) async {
    final plan = AlertPlanner.plan(reminder, _settings(), _clock.now());
    for (final alert in plan) {
      await _scheduler.schedule(alert, contentFor(reminder, alert));
    }
  }

  AlertContent contentFor(Reminder reminder, PlannedAlert alert) {
    final when = _l10n.dayAndTime(reminder.dueAt, alert.at);
    final String body;
    if (alert.isEscalation) {
      body = _l10n.alertStillPending(when);
    } else {
      final remaining = reminder.dueAt.difference(alert.at);
      body = remaining.inMinutes > 0
          ? _l10n.alertBodyWithLead(when, _l10n.duration(remaining))
          : when;
    }
    return AlertContent(title: reminder.title, body: body);
  }
}
