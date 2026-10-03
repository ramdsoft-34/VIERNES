import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:viernes/core/logging/app_logger.dart';
import 'package:viernes/core/platform/device_data.dart';
import 'package:viernes/features/settings/domain/app_settings.dart';
import 'package:viernes/features/settings/presentation/settings_controller.dart';

/// Datos del teléfono (calendario, contactos, carro). En pruebas, uno falso.
final deviceDataProvider = Provider<DeviceData>(
  (ref) => const AndroidDeviceData(),
);

/// Lee el calendario del teléfono solo si el usuario lo activó y dio el
/// permiso. Sin eso devuelve una lista vacía.
class CalendarReader {
  CalendarReader(this._device, this._enabled);

  final DeviceData _device;
  final bool Function() _enabled;

  Future<List<CalendarEvent>> events(DateTime from, DateTime to) async {
    if (!_enabled()) return const [];
    try {
      if (!await _device.hasCalendarPermission()) return const [];
      return await _device.calendarEvents(from, to);
    } on Object catch (error) {
      AppLogger.info('No se pudo leer el calendario: $error');
      return const [];
    }
  }
}

final calendarReaderProvider = Provider<CalendarReader>(
  (ref) => CalendarReader(
    ref.watch(deviceDataProvider),
    () => ref.read(settingsControllerProvider).includeCalendar,
  ),
);

/// Eventos del calendario de un día (para la pantalla Calendario).
final FutureProviderFamily<List<CalendarEvent>, DateTime>
calendarDayEventsProvider = FutureProvider.autoDispose
    .family<List<CalendarEvent>, DateTime>((ref, day) {
      ref.watch(settingsControllerProvider.select((s) => s.includeCalendar));
      final start = DateTime(day.year, day.month, day.day);
      return ref
          .watch(calendarReaderProvider)
          .events(start, start.add(const Duration(days: 1)));
    });

/// Eventos del calendario de un mes (marcas en la pantalla Calendario).
final FutureProviderFamily<List<CalendarEvent>, DateTime>
calendarMonthEventsProvider = FutureProvider.autoDispose
    .family<List<CalendarEvent>, DateTime>((ref, month) {
      ref.watch(settingsControllerProvider.select((s) => s.includeCalendar));
      final start = DateTime(month.year, month.month - 1, 20);
      final end = DateTime(month.year, month.month + 1, 12);
      return ref.watch(calendarReaderProvider).events(start, end);
    });

/// Decide si las respuestas deben ser cortas (modo conducción).
class DrivingDetector {
  DrivingDetector(this._device, this._mode);

  final DeviceData _device;
  final DrivingMode Function() _mode;

  Future<bool> isActive() async {
    switch (_mode()) {
      case DrivingMode.off:
        return false;
      case DrivingMode.on:
        return true;
      case DrivingMode.auto:
        try {
          return await _device.isDriving();
        } on Object {
          return false;
        }
    }
  }
}

final drivingDetectorProvider = Provider<DrivingDetector>(
  (ref) => DrivingDetector(
    ref.watch(deviceDataProvider),
    () => ref.read(settingsControllerProvider).drivingMode,
  ),
);
