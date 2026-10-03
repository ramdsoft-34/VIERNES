import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:viernes/ai/learning/snooze_habits.dart';
import 'package:viernes/app/providers.dart';
import 'package:viernes/app/router/app_router.dart';
import 'package:viernes/app/router/routes.dart';
import 'package:viernes/core/logging/app_logger.dart';
import 'package:viernes/features/alerts/application/alert_action_handler.dart';
import 'package:viernes/features/alerts/application/reminder_alert_sync.dart';
import 'package:viernes/features/alerts/data/notification_service.dart';
import 'package:viernes/features/alerts/domain/alert_scheduler.dart';
import 'package:viernes/features/device/device_providers.dart';
import 'package:viernes/features/reminders/domain/entities/reminder_enums.dart';
import 'package:viernes/features/reminders/presentation/providers/reminder_providers.dart';
import 'package:viernes/features/settings/domain/app_settings.dart';
import 'package:viernes/features/settings/presentation/settings_controller.dart';
import 'package:viernes/features/summaries/application/agenda_sync.dart';
import 'package:viernes/features/summaries/data/home_widget_service.dart';
import 'package:viernes/l10n/gen/app_localizations.dart';

/// Cuánto suele posponer el usuario (lo aprende de sus elecciones).
final snoozeHabitsProvider = Provider<SnoozeHabits>(
  (ref) => SnoozeHabits(ref.watch(sharedPreferencesProvider)),
);

/// Tiempo de «Recordar después» sin elegir: lo aprendido o el de Ajustes.
final preferredSnoozeProvider = Provider<Duration Function()>((ref) {
  final habits = ref.watch(snoozeHabitsProvider);
  return () {
    final settings = ref.read(settingsControllerProvider);
    return habits.preferred(
      settings.snoozeDuration,
      enabled: settings.personalLearning,
    );
  };
});

final notificationServiceProvider = Provider<NotificationService>((ref) {
  final service = NotificationService(
    settings: () => ref.read(settingsControllerProvider),
    l10n: lookupAppLocalizations(const Locale('es')),
    snoozeDuration: () => ref.read(preferredSnoozeProvider)(),
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
    snoozeDuration: () => ref.read(preferredSnoozeProvider)(),
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
    loadEvents: ref.watch(calendarReaderProvider).events,
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
        previous.nightSummaryTime != next.nightSummaryTime ||
        previous.includeCalendar != next.includeCalendar ||
        previous.snoozeDuration != next.snoozeDuration;
    if (changed) unawaited(coordinator.resyncAll());
  });
  // Llamadas separadas para leer la configuración del provider paso a paso.
  // ignore: cascade_invocations
  ref.onDispose(coordinator.dispose);
  return coordinator;
});

/// Pedidos de leer el resumen del día (notificación de la mañana, acceso
/// directo). La pantalla de inicio los atiende abriendo la conversación.
class BriefingRequests {
  final _requests = StreamController<void>.broadcast();
  bool _pending = false;

  Stream<void> get stream => _requests.stream;

  void request() {
    _pending = true;
    _requests.add(null);
  }

  /// `true` si hay un pedido sin atender (y lo marca como atendido).
  bool consume() {
    final pending = _pending;
    _pending = false;
    return pending;
  }

  void dispose() => unawaited(_requests.close());
}

final briefingRequestsProvider = Provider<BriefingRequests>((ref) {
  final requests = BriefingRequests();
  ref.onDispose(requests.dispose);
  return requests;
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
      if (response.actionId == AlertActions.listenSummary ||
          (response.actionId == null &&
              reminderId == AlertActions.morningPayload &&
              _ref.read(settingsControllerProvider).speakBriefing)) {
        _ref.read(appRouterProvider).go(AppRoutes.home);
        _ref.read(briefingRequestsProvider).request();
      } else if (response.actionId != null) {
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
