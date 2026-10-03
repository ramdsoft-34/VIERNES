extension DateX on DateTime {
  DateTime get startOfDay => DateTime(year, month, day);

  DateTime get endOfDay => DateTime(year, month, day + 1);

  bool isSameDay(DateTime other) =>
      year == other.year && month == other.month && day == other.day;

  /// Lunes de la semana a la que pertenece esta fecha.
  DateTime get startOfWeek => DateTime(year, month, day - (weekday - 1));

  /// Misma hora de reloj, desplazada [days] días de calendario.
  ///
  /// Usa el constructor local en vez de sumar `Duration` para no correr la
  /// hora cuando hay cambios de horario.
  DateTime addDays(int days) =>
      DateTime(year, month, day + days, hour, minute, second);

  /// Suma meses conservando el día cuando existe; si no, usa el último día
  /// del mes destino (31 ene + 1 mes → 28/29 feb).
  DateTime addMonthsClamped(int months, {int? anchorDay}) {
    final targetFirst = DateTime(year, month + months);
    final lastDay = DateTime(targetFirst.year, targetFirst.month + 1, 0).day;
    final wanted = anchorDay ?? day;
    return DateTime(
      targetFirst.year,
      targetFirst.month,
      wanted > lastDay ? lastDay : wanted,
      hour,
      minute,
      second,
    );
  }

  DateTime withTime(int hour, int minute) =>
      DateTime(year, month, day, hour, minute);
}
