import 'dart:ui';

import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:viernes/core/database/app_database.dart';
import 'package:viernes/core/logging/app_logger.dart';
import 'package:viernes/core/utils/clock.dart';
import 'package:viernes/features/alerts/application/alert_action_handler.dart';
import 'package:viernes/features/alerts/application/reminder_alert_sync.dart';
import 'package:viernes/features/alerts/application/scheduling_reminder_repository.dart';
import 'package:viernes/features/alerts/data/notification_service.dart';
import 'package:viernes/features/reminders/data/drift_reminder_repository.dart';
import 'package:viernes/features/reminders/domain/entities/reminder_enums.dart';
import 'package:viernes/features/reminders/domain/usecases/complete_reminder.dart';
import 'package:viernes/features/reminders/domain/usecases/move_overdue_to_tomorrow.dart';
import 'package:viernes/features/reminders/domain/usecases/snooze_reminder.dart';
import 'package:viernes/features/settings/data/settings_repository.dart';
import 'package:viernes/features/summaries/application/agenda_sync.dart';
import 'package:viernes/features/summaries/data/home_widget_service.dart';
import 'package:viernes/l10n/gen/app_localizations.dart';

/// Punto de entrada cuando se toca "Ya lo hice" o "Recordar después" con la
/// app cerrada. Android lo ejecuta en un proceso de Flutter aparte, sin UI,
/// así que aquí se arman a mano las mismas piezas que usa la app.
@pragma('vm:entry-point')
Future<void> onBackgroundNotificationResponse(
  NotificationResponse response,
) async {
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();
  AppDatabase? db;
  try {
    Intl.defaultLocale = 'es';
    await initializeDateFormatting('es');
    final prefs = await SharedPreferences.getInstance();
    final settings = SettingsRepository(prefs).load();
    final l10n = lookupAppLocalizations(const Locale('es'));
    const clock = SystemClock();

    final notifications = NotificationService(
      settings: () => settings,
      l10n: l10n,
    );
    await notifications.initialize(foreground: false);

    db = AppDatabase.open();
    final local = DriftReminderRepository(db);
    final agenda = AgendaSync(
      summaries: notifications,
      widget: const HomeWidgetService(),
      settings: () => settings,
      clock: clock,
      loadActive: () => local.watchByStatus({
        ReminderStatus.pending,
        ReminderStatus.snoozed,
      }).first,
    );
    final repository = SchedulingReminderRepository(
      local,
      ReminderAlertSync(
        scheduler: notifications,
        settings: () => settings,
        clock: clock,
        l10n: l10n,
      ),
      onChanged: agenda.refresh,
    );
    final handler = AlertActionHandler(
      complete: CompleteReminder(repository, clock),
      snooze: SnoozeReminder(repository, clock),
      snoozeDuration: () => settings.snoozeDuration,
      moveOverdue: MoveOverdueToTomorrow(repository, clock),
    );
    final payload = response.payload ?? '';
    if (payload.startsWith(AlertActions.summaryPayloadPrefix)) {
      await handler.handleSummaryAction(response.actionId);
    } else {
      await handler.handle(actionId: response.actionId, reminderId: payload);
    }
  } on Object catch (error, stack) {
    AppLogger.error(
      'Error al responder desde la notificación',
      error: error,
      stackTrace: stack,
    );
  } finally {
    await db?.close();
  }
}
