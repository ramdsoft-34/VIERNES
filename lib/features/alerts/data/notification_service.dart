import 'dart:async';

import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;
import 'package:viernes/core/logging/app_logger.dart';
import 'package:viernes/core/platform/system_bridge.dart';
import 'package:viernes/features/alerts/application/alert_action_handler.dart';
import 'package:viernes/features/alerts/data/background_alert_handler.dart';
import 'package:viernes/features/alerts/domain/alert_scheduler.dart';
import 'package:viernes/features/alerts/domain/notification_ids.dart';
import 'package:viernes/features/alerts/domain/planned_alert.dart';
import 'package:viernes/features/settings/domain/app_settings.dart';
import 'package:viernes/features/sharing/application/shared_inbox.dart';
import 'package:viernes/features/summaries/application/agenda_sync.dart';
import 'package:viernes/features/summaries/domain/summary_planner.dart';
import 'package:viernes/l10n/gen/app_localizations.dart';

/// Estado de los permisos que necesitan los avisos.
@immutable
class AlertPermissions {
  const AlertPermissions({
    required this.notifications,
    required this.exactAlarms,
    required this.fullScreen,
  });

  final bool notifications;
  final bool exactAlarms;
  final bool fullScreen;

  /// Lo mínimo para que los avisos lleguen a tiempo.
  bool get essentialsGranted => notifications && exactAlarms;
}

/// Notificaciones locales y alarmas exactas de Android.
class NotificationService
    implements AlertScheduler, SummaryScheduler, InfoNotifier {
  NotificationService({
    required this._settings,
    required this._l10n,
    FlutterLocalNotificationsPlugin? plugin,
    this._bridge = const SystemBridge(),
  }) : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final AppSettings Function() _settings;
  final AppLocalizations _l10n;
  final FlutterLocalNotificationsPlugin _plugin;
  final SystemBridge _bridge;

  final _responses = StreamController<NotificationResponse>.broadcast();
  bool _exactAllowed = true;

  /// Hace que el sonido se repita hasta que se atienda (FLAG_INSISTENT).
  static const _flagInsistent = 4;
  static const _brandColor = Color(0xFF5B4CF0);
  static const _icon = 'ic_stat_viernes';

  /// Toques en la notificación o sus botones con la app abierta.
  Stream<NotificationResponse> get responses => _responses.stream;

  AndroidFlutterLocalNotificationsPlugin? get _android => _plugin
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >();

  /// Configura zona horaria y notificaciones. Devuelve la notificación que
  /// abrió la app, si fue así.
  Future<NotificationResponse?> initialize({bool foreground = true}) async {
    await configureLocalTimeZone();
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings(_icon),
      ),
      onDidReceiveNotificationResponse: foreground ? _responses.add : null,
      onDidReceiveBackgroundNotificationResponse:
          onBackgroundNotificationResponse,
    );
    _exactAllowed = await _android?.canScheduleExactNotifications() ?? true;
    if (!foreground) return null;
    final launch = await _plugin.getNotificationAppLaunchDetails();
    return launch?.didNotificationLaunchApp ?? false
        ? launch!.notificationResponse
        : null;
  }

  static Future<void> configureLocalTimeZone() async {
    tz_data.initializeTimeZones();
    try {
      final zone = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(zone.identifier));
    } on Object catch (error) {
      // Colombia por defecto: UTC-5 sin horario de verano.
      AppLogger.error('Zona horaria desconocida', error: error);
      tz.setLocalLocation(tz.getLocation('America/Bogota'));
    }
  }

  // --- AlertScheduler -------------------------------------------------------

  @override
  Future<void> schedule(PlannedAlert alert, AlertContent content) async {
    await _plugin.zonedSchedule(
      id: alert.notificationId,
      title: content.title,
      body: content.body,
      payload: alert.reminderId,
      scheduledDate: tz.TZDateTime.from(alert.at, tz.local),
      notificationDetails: NotificationDetails(
        android: _details(alert, content),
      ),
      androidScheduleMode: _exactAllowed
          ? AndroidScheduleMode.exactAllowWhileIdle
          : AndroidScheduleMode.inexactAllowWhileIdle,
    );
  }

  @override
  Future<void> cancel(Iterable<int> notificationIds) async {
    for (final id in notificationIds) {
      await _plugin.cancel(id: id);
    }
  }

  @override
  Future<void> cancelAll() async {
    final pending = await _plugin.pendingNotificationRequests();
    for (final request in pending) {
      if (request.id < NotificationIds.reservedBase) {
        await _plugin.cancel(id: request.id);
      }
    }
  }

  AndroidNotificationDetails _details(
    PlannedAlert alert,
    AlertContent content,
  ) {
    final settings = _settings();
    final sound = settings.soundEnabled && !alert.silent;
    final vibration = settings.vibrationEnabled && !alert.silent;
    // En Android 8+ sonido y vibración pertenecen al canal y no se pueden
    // cambiar después: cada combinación usa su propio canal.
    final String channelId;
    final String channelName;
    if (alert.silent) {
      channelId = 'alerts_silent';
      channelName = _l10n.channelSilent;
    } else {
      final variant = 's${sound ? 1 : 0}v${vibration ? 1 : 0}';
      channelId = alert.urgent
          ? 'alerts_urgent_$variant'
          : 'alerts_normal_$variant';
      channelName = alert.urgent ? _l10n.channelUrgent : _l10n.channelReminders;
    }

    return AndroidNotificationDetails(
      channelId,
      channelName,
      channelDescription: _l10n.channelDescription,
      icon: _icon,
      color: _brandColor,
      importance: alert.silent
          ? Importance.low
          : (alert.urgent ? Importance.max : Importance.high),
      priority: alert.silent ? Priority.low : Priority.max,
      playSound: sound,
      enableVibration: vibration,
      silent: alert.silent,
      category: AndroidNotificationCategory.alarm,
      fullScreenIntent: alert.fullScreen,
      audioAttributesUsage: alert.urgent
          ? AudioAttributesUsage.alarm
          : AudioAttributesUsage.notification,
      additionalFlags: alert.insistent
          ? Int32List.fromList([_flagInsistent])
          : null,
      styleInformation: BigTextStyleInformation(content.body),
      ticker: content.title,
      when: alert.at.millisecondsSinceEpoch,
      actions: [
        AndroidNotificationAction(
          AlertActions.complete,
          '✓ ${_l10n.actionComplete}',
        ),
        AndroidNotificationAction(
          AlertActions.snooze,
          '⏰ ${_l10n.actionSnooze}',
        ),
      ],
    );
  }

  // --- Resúmenes diarios ---------------------------------------------------

  @override
  Future<void> replaceSummaries(List<PlannedSummary> summaries) async {
    for (final id in SummaryPlanner.allIds) {
      await _plugin.cancel(id: id);
    }
    for (final summary in summaries) {
      await _plugin.zonedSchedule(
        id: summary.notificationId,
        title: summary.title,
        body: summary.body,
        payload: summary.payload,
        scheduledDate: tz.TZDateTime.from(summary.at, tz.local),
        notificationDetails: NotificationDetails(
          android: AndroidNotificationDetails(
            'summaries',
            _l10n.channelSummaries,
            channelDescription: _l10n.channelSummariesDescription,
            icon: _icon,
            color: _brandColor,
            category: AndroidNotificationCategory.reminder,
            styleInformation: BigTextStyleInformation(summary.body),
            number: summary.count,
            actions: summary.kind == SummaryKind.night
                ? [
                    AndroidNotificationAction(
                      AlertActions.moveToTomorrow,
                      _l10n.summaryMoveToTomorrow,
                    ),
                  ]
                : null,
          ),
        ),
        // Un resumen no necesita precisión de alarma.
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      );
    }
  }

  // --- Avisos inmediatos (compartidos) -----------------------------------

  @override
  Future<void> showInfo({
    required int id,
    required String title,
    required String body,
  }) => _plugin.show(
    id: id,
    title: title,
    body: body,
    notificationDetails: const NotificationDetails(
      android: AndroidNotificationDetails(
        'sharing',
        'Compartidos',
        channelDescription:
            'Recordatorios que te envían y avisos cuando alguien completa '
            'lo que le enviaste',
        icon: _icon,
        color: _brandColor,
        importance: Importance.high,
        priority: Priority.high,
      ),
    ),
  );

  // --- Permisos -----------------------------------------------------------

  Future<AlertPermissions> checkPermissions() async {
    final android = _android;
    return AlertPermissions(
      notifications: await android?.areNotificationsEnabled() ?? true,
      exactAlarms: await android?.canScheduleExactNotifications() ?? true,
      fullScreen: await _bridge.canUseFullScreenIntent(),
    );
  }

  Future<void> requestNotifications() async =>
      _android?.requestNotificationsPermission();

  Future<void> requestExactAlarms() async {
    await _android?.requestExactAlarmsPermission();
    _exactAllowed = await _android?.canScheduleExactNotifications() ?? true;
  }

  Future<void> requestFullScreen() async =>
      _android?.requestFullScreenIntentPermission();

  Future<void> dispose() => _responses.close();
}
