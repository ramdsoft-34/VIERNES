import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:viernes/app/providers.dart';
import 'package:viernes/app/router/app_router.dart';
import 'package:viernes/app/router/routes.dart';
import 'package:viernes/core/logging/app_logger.dart';
import 'package:viernes/features/alerts/application/alert_action_handler.dart';
import 'package:viernes/features/alerts/application/reminder_alert_sync.dart';
import 'package:viernes/features/alerts/data/notification_service.dart';
import 'package:viernes/features/alerts/domain/alert_scheduler.dart';
import 'package:viernes/features/reminders/domain/entities/reminder_enums.dart';
import 'package:viernes/features/reminders/presentation/providers/reminder_providers.dart';
import 'package:viernes/features/settings/domain/app_settings.dart';
import 'package:viernes/features/settings/presentation/settings_controller.dart';
import 'package:viernes/features/summaries/application/agenda_sync.dart';
import 'package:viernes/features/summaries/data/home_widget_service.dart';
import 'package:viernes/l10n/gen/app_localizations.dart';

final notificationServiceProvider = Provider<NotificationService>((ref) {
  final service = NotificationService(
    settings: () => ref.read(settingsControllerProvider),
    l10n: lookupAppLocalizations(const Locale('es')),
  );
  ref.onDispose(service.dispose);
  return service;
});

/// Programador de avisos. En pruebas se sobrescribe con uno falso.
final alertSchedulerProvider = Provider<AlertScheduler>(
  (ref) => ref.watch(notificationServiceProvider),
);

final reminderAlertSyncProvider = Provider<ReminderAlertSync>(
  (ref) => ReminderAlertSync(
    scheduler: ref.watch(alertSchedulerProvider),
    settings: () => ref.read(settingsControllerProvider),
    clock: ref.watch(clockProvider),
    l10n: lookupAppLocalizations(const Locale('es')),
  ),
);

final alertActionHandlerProvider = Provider<AlertActionHandler>(
  (ref) => AlertActionHandler(
    complete: ref.watch(completeReminderProvider),
    snooze: ref.watch(snoozeReminderProvider),
    snoozeDuration: () => ref.read(settingsControllerProvider).snoozeDuration,
    moveOverdue: ref.watch(moveOverdueToTomorrowProvider),
  ),
);

/// Resúmenes diarios. En pruebas se sobrescribe con uno falso.
final summarySchedulerProvider = Provider<SummaryScheduler>(
  (ref) => ref.watch(notificationServiceProvider),
);

final homeWidgetUpdaterProvider = Provider<HomeWidgetUpdater>(
  (ref) => const HomeWidgetService(),
);

final agendaSyncProvider = Provider<AgendaSync>(
  (ref) => AgendaSync(
    summaries: ref.watch(summarySchedulerProvider),
    widget: ref.watch(homeWidgetUpdaterProvider),
    settings: () => ref.read(settingsControllerProvider),
    clock: ref.watch(clockProvider),
    loadActive: () => ref.read(localReminderRepositoryProvider).watchByStatus({
      ReminderStatus.pending,
      ReminderStatus.snoozed,
    }).first,
  ),
);

final FutureProvider<AlertPermissions> alertPermissionsProvider =
    FutureProvider.autoDispose<AlertPermissions>(
      (ref) => ref.watch(notificationServiceProvider).checkPermissions(),
    );

final alertCoordinatorProvider = Provider<AlertCoordinator>((ref) {
  final coordinator = AlertCoordinator(ref);
  // Cambios de ajustes que alteran cómo se avisa: rehacer el plan.
  ref.listen<AppSettings>(settingsControllerProvider, (previous, next) {
    if (previous == null) return;
    final changed =
        previous.escalationEnabled != next.escalationEnabled ||
        previous.fullScreenAlerts != next.fullScreenAlerts ||
        previous.soundEnabled != next.soundEnabled ||
        previous.vibrationEnabled != next.vibrationEnabled ||
        previous.quietHoursEnabled != next.quietHoursEnabled ||
        previous.quietHoursStart != next.quietHoursStart ||
        previous.quietHoursEnd != next.quietHoursEnd ||
        previous.morningSummaryEnabled != next.morningSummaryEnabled ||
        previous.morningSummaryTime != next.morningSummaryTime ||
        previous.nightSummaryEnabled != next.nightSummaryEnabled ||
        previous.nightSummaryTime != next.nightSummaryTime;
    if (changed) unawaited(coordinator.resyncAll());
  });
  // Llamadas separadas para leer la configuración del provider paso a paso.
  // ignore: cascade_invocations
  ref.onDispose(coordinator.dispose);
  return coordinator;
});

/// Conecta las notificaciones con la app: abre la alerta al tocarlas,
/// atiende sus botones y mantiene el plan de avisos al día.
class AlertCoordinator with WidgetsBindingObserver {
  AlertCoordinator(this._ref);

  final Ref _ref;
  StreamSubscription<NotificationResponse>? _subscription;

  void start() {
    _subscription = _ref
        .read(notificationServiceProvider)
        .responses
        .listen(_onResponse);
    WidgetsBinding.instance.addObserver(this);
    unawaited(resyncAll());
  }

  Future<void> _onResponse(NotificationResponse response) async {
    final reminderId = response.payload;
    if (reminderId == null) return;
    if (reminderId.startsWith(AlertActions.summaryPayloadPrefix)) {
      if (response.actionId != null) {
        await _ref
            .read(alertActionHandlerProvider)
            .handleSummaryAction(response.actionId);
      } else {
        _ref.read(appRouterProvider).go(AppRoutes.home);
      }
      return;
    }
    if (response.actionId != null) {
      await _ref
          .read(alertActionHandlerProvider)
          .handle(actionId: response.actionId, reminderId: reminderId);
      return;
    }
    // Toque en la notificación o alerta a pantalla completa.
    unawaited(_ref.read(appRouterProvider).push(AppRoutes.alert(reminderId)));
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    // Pudo cambiar algo desde la notificación con la app en segundo plano.
    _ref.read(appDatabaseProvider).refreshAll();
    _ref.invalidate(alertPermissionsProvider);
    unawaited(resyncAll());
  }

  /// Reprograma todos los avisos según el estado actual.
  Future<void> resyncAll() async {
    try {
      final active = await _ref.read(reminderRepositoryProvider).watchByStatus({
        ReminderStatus.pending,
        ReminderStatus.snoozed,
      }).first;
      await _ref.read(reminderAlertSyncProvider).syncAll(active);
      await _ref.read(agendaSyncProvider).refresh();
    } on Object catch (error, stack) {
      AppLogger.error(
        'No se pudieron reprogramar los avisos',
        error: error,
        stackTrace: stack,
      );
    }
  }

  void dispose() {
    unawaited(_subscription?.cancel());
    WidgetsBinding.instance.removeObserver(this);
  }
}
