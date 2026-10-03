import 'package:flutter/foundation.dart';

/// Hora del día sin fecha (independiente de Flutter para mantener el dominio
/// puro).
@immutable
class DayTime {
  const DayTime(this.hour, this.minute)
    : assert(hour >= 0 && hour < 24, 'hora inválida'),
      assert(minute >= 0 && minute < 60, 'minuto inválido');

  factory DayTime.fromMinutes(int minutes) =>
      DayTime((minutes ~/ 60) % 24, minutes % 60);

  final int hour;
  final int minute;

  int get inMinutes => hour * 60 + minute;

  @override
  bool operator ==(Object other) =>
      other is DayTime && other.hour == hour && other.minute == minute;

  @override
  int get hashCode => Object.hash(hour, minute);
}
