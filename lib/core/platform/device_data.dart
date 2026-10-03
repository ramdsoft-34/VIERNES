import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:viernes/core/logging/app_logger.dart';

/// Un evento del calendario del teléfono (Google Calendar se sincroniza con
/// él). Solo se lee; Viernes nunca lo modifica.
@immutable
class CalendarEvent {
  const CalendarEvent({
    required this.title,
    required this.start,
    required this.end,
    this.allDay = false,
    this.calendar = '',
    this.location,
  });

  factory CalendarEvent.fromMap(Map<Object?, Object?> map) {
    final allDay = map['allDay'] == true;
    DateTime read(Object? millis) {
      final value = DateTime.fromMillisecondsSinceEpoch(
        (millis as num?)?.toInt() ?? 0,
        isUtc: allDay,
      );
      // Los eventos de todo el día se guardan en UTC: se conserva la fecha.
      return allDay
          ? DateTime(value.year, value.month, value.day)
          : value.toLocal();
    }

    return CalendarEvent(
      title: (map['title'] as String?)?.trim().isNotEmpty ?? false
          ? (map['title']! as String).trim()
          : 'Evento',
      start: read(map['start']),
      end: read(map['end']),
      allDay: allDay,
      calendar: map['calendar'] as String? ?? '',
      location: (map['location'] as String?)?.trim().isEmpty ?? true
          ? null
          : map['location']! as String,
    );
  }

  final String title;
  final DateTime start;
  final DateTime end;
  final bool allDay;

  /// Nombre del calendario («Trabajo», el correo de la cuenta…).
  final String calendar;
  final String? location;

  @override
  bool operator ==(Object other) =>
      other is CalendarEvent &&
      other.title == title &&
      other.start == start &&
      other.end == end &&
      other.allDay == allDay;

  @override
  int get hashCode => Object.hash(title, start, end, allDay);

  @override
  String toString() => 'CalendarEvent($title @ $start)';
}

/// Cumpleaños guardado en un contacto del teléfono.
@immutable
class ContactBirthday {
  const ContactBirthday({
    required this.name,
    required this.month,
    required this.day,
    this.year,
  });

  final String name;
  final int month;
  final int day;

  /// Año de nacimiento, si el contacto lo tiene.
  final int? year;

  /// Identifica el cumpleaños para no importarlo dos veces.
  String get key => '${name.trim().toLowerCase()}|$month-$day';

  /// Próxima fecha del cumpleaños (hoy cuenta) a la hora [hour]:[minute].
  DateTime next(DateTime now, {int hour = 8, int minute = 0}) {
    DateTime at(int y) {
      // 29 de febrero en años no bisiestos: el 28.
      final lastDay = DateTime(y, month + 1, 0).day;
      return DateTime(y, month, day > lastDay ? lastDay : day, hour, minute);
    }

    final today = DateTime(now.year, now.month, now.day);
    final thisYear = at(now.year);
    return DateTime(thisYear.year, thisYear.month, thisYear.day).isBefore(today)
        ? at(now.year + 1)
        : thisYear;
  }

  /// Años que cumple en [on], si se conoce el año de nacimiento.
  int? ageOn(DateTime on) => year == null ? null : on.year - year!;

  @override
  bool operator ==(Object other) =>
      other is ContactBirthday &&
      other.name == name &&
      other.month == month &&
      other.day == day &&
      other.year == year;

  @override
  int get hashCode => Object.hash(name, month, day, year);
}

/// Datos del teléfono que Viernes puede leer con permiso: calendario,
/// cumpleaños de los contactos y si se va conduciendo.
abstract interface class DeviceData {
  Future<bool> hasCalendarPermission();

  Future<bool> requestCalendarPermission();

  /// Eventos que se cruzan con `[from, to)`, ordenados por inicio.
  Future<List<CalendarEvent>> calendarEvents(DateTime from, DateTime to);

  Future<bool> hasContactsPermission();

  Future<bool> requestContactsPermission();

  Future<List<ContactBirthday>> birthdays();

  /// Modo carro de Android o conectado al Bluetooth de un carro.
  Future<bool> isDriving();

  /// Android 12+: permiso para saber si hay un carro conectado.
  Future<bool> requestBluetoothPermission();

  /// Abre los ajustes del asistente y la entrada de voz del teléfono.
  Future<void> openAssistantSettings();
}

/// Implementación con `DeviceDataChannel.kt`.
class AndroidDeviceData implements DeviceData {
  const AndroidDeviceData();

  static const _channel = MethodChannel('com.ramdsoft.viernes/device');

  @override
  Future<bool> hasCalendarPermission() async =>
      await _call<bool>('hasCalendarPermission') ?? false;

  @override
  Future<bool> requestCalendarPermission() async =>
      await _call<bool>('requestCalendarPermission') ?? false;

  @override
  Future<List<CalendarEvent>> calendarEvents(DateTime from, DateTime to) async {
    final raw = await _call<List<Object?>>('calendarEvents', {
      'from': from.millisecondsSinceEpoch,
      'to': to.millisecondsSinceEpoch,
    });
    final events = [
      for (final item in raw ?? const <Object?>[])
        if (item is Map) CalendarEvent.fromMap(item),
    ]..sort((a, b) => a.start.compareTo(b.start));
    return events;
  }

  @override
  Future<bool> hasContactsPermission() async =>
      await _call<bool>('hasContactsPermission') ?? false;

  @override
  Future<bool> requestContactsPermission() async =>
      await _call<bool>('requestContactsPermission') ?? false;

  @override
  Future<List<ContactBirthday>> birthdays() async {
    final raw = await _call<List<Object?>>('birthdays');
    final seen = <String>{};
    final result = <ContactBirthday>[];
    for (final item in raw ?? const <Object?>[]) {
      if (item is! Map) continue;
      final birthday = parseBirthday(
        item['name'] as String? ?? '',
        item['date'] as String? ?? '',
      );
      if (birthday != null && seen.add(birthday.key)) result.add(birthday);
    }
    result.sort((a, b) => a.name.compareTo(b.name));
    return result;
  }

  @override
  Future<bool> isDriving() async => await _call<bool>('isDriving') ?? false;

  @override
  Future<bool> requestBluetoothPermission() async =>
      await _call<bool>('requestBluetoothPermission') ?? false;

  @override
  Future<void> openAssistantSettings() => _call<void>('openAssistantSettings');

  Future<T?> _call<T>(String method, [Map<String, Object?>? args]) async {
    try {
      return await _channel.invokeMethod<T>(method, args);
    } on MissingPluginException {
      return null;
    } on PlatformException catch (error) {
      AppLogger.error('Datos del teléfono: $method', error: error);
      return null;
    }
  }
}

/// Android guarda la fecha como `1990-05-12`, `--05-12` (sin año) o, en
/// algunos teléfonos, `12/05/1990`.
@visibleForTesting
ContactBirthday? parseBirthday(String name, String raw) {
  final trimmedName = name.trim();
  if (trimmedName.isEmpty) return null;
  final value = raw.trim();
  final iso = RegExp(r'^(\d{4}|-)-?(\d{1,2})-(\d{1,2})').firstMatch(value);
  final slash = RegExp(r'^(\d{1,2})/(\d{1,2})(?:/(\d{4}))?$').firstMatch(value);
  int? year;
  int month;
  int day;
  if (iso != null) {
    year = int.tryParse(iso.group(1)!);
    month = int.parse(iso.group(2)!);
    day = int.parse(iso.group(3)!);
  } else if (slash != null) {
    day = int.parse(slash.group(1)!);
    month = int.parse(slash.group(2)!);
    year = int.tryParse(slash.group(3) ?? '');
  } else {
    return null;
  }
  if (month < 1 || month > 12 || day < 1 || day > 31) return null;
  // Algunos teléfonos usan 1604 como «año desconocido».
  if (year != null && (year < 1900 || year > 2100)) year = null;
  return ContactBirthday(name: trimmedName, month: month, day: day, year: year);
}
