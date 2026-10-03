import 'package:flutter/foundation.dart';
import 'package:viernes/core/logging/app_logger.dart';
import 'package:viernes/core/platform/device_data.dart';
import 'package:viernes/core/utils/clock.dart';
import 'package:viernes/features/reminders/domain/entities/reminder.dart';
import 'package:viernes/features/settings/domain/app_settings.dart';
import 'package:viernes/features/summaries/domain/summary_planner.dart';

/// Programa los resúmenes diarios en el sistema.
abstract interface class SummaryScheduler {
  /// Reemplaza todos los resúmenes programados por [summaries].
  Future<void> replaceSummaries(List<PlannedSummary> summaries);
}

/// Un recordatorio tal como lo muestra el widget de la pantalla de inicio.
@immutable
class WidgetItem {
  const WidgetItem({required this.title, required this.at});

  final String title;
  final DateTime at;

  Map<String, Object> toJson() => {
    't': title,
    'd': at.millisecondsSinceEpoch,
  };
}

/// Actualiza el widget de la pantalla de inicio.
abstract interface class HomeWidgetUpdater {
  Future<void> update(List<WidgetItem> items);
}

/// Mantiene al día lo que depende de toda la agenda: resúmenes de la mañana
/// y la noche, y el widget.
class AgendaSync {
  AgendaSync({
    required this._summaries,
    required this._widget,
    required this._settings,
    required this._clock,
    required this._loadActive,
    this._loadEvents,
  });

  final SummaryScheduler _summaries;
  final HomeWidgetUpdater _widget;
  final AppSettings Function() _settings;
  final Clock _clock;
  final Future<List<Reminder>> Function() _loadActive;

  /// Eventos del calendario del teléfono entre dos fechas (si el usuario lo
  /// permitió); se mencionan en el resumen de la mañana.
  final Future<List<CalendarEvent>> Function(DateTime from, DateTime to)?
  _loadEvents;

  /// El widget muestra los próximos; se envían algunos de más para que, al
  /// redibujarse más tarde, aún tenga qué mostrar.
  static const widgetItems = 10;

  Future<void>? _running;
  bool _again = false;

  /// Recalcula todo. Si ya hay un cálculo en curso (p. ej. se movieron varios
  /// recordatorios seguidos), se hace uno más al terminar en vez de varios.
  Future<void> refresh() {
    if (_running != null) {
      _again = true;
      return _running!;
    }
    return _running = _loop().whenComplete(() => _running = null);
  }

  Future<void> _loop() async {
    do {
      _again = false;
      await _refreshOnce();
    } while (_again);
  }

  Future<void> _refreshOnce() async {
    final List<Reminder> active;
    try {
      active = await _loadActive();
    } on Object catch (error) {
      AppLogger.error('No se pudo leer la agenda', error: error);
      return;
    }
    final now = _clock.now();

    var events = const <CalendarEvent>[];
    final loadEvents = _loadEvents;
    if (loadEvents != null) {
      try {
        final today = DateTime(now.year, now.month, now.day);
        events = await loadEvents(
          today,
          today.add(const Duration(days: SummaryPlanner.days)),
        );
      } on Object catch (error) {
        AppLogger.info('Calendario no disponible: $error');
      }
    }

    try {
      await _summaries.replaceSummaries(
        SummaryPlanner.plan(
          active: active,
          settings: _settings(),
          now: now,
          events: events,
        ),
      );
    } on Object catch (error) {
      AppLogger.error('No se pudieron programar los resúmenes', error: error);
    }

    try {
      final upcoming = active.where((r) => r.isActive).toList()
        ..sort((a, b) => a.nextTriggerAt.compareTo(b.nextTriggerAt));
      await _widget.update([
        for (final reminder in upcoming.take(widgetItems))
          WidgetItem(title: reminder.title, at: reminder.dueAt),
      ]);
    } on Object catch (error) {
      AppLogger.error('No se pudo actualizar el widget', error: error);
    }
  }
}
