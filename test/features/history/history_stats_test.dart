import 'package:flutter_test/flutter_test.dart';
import 'package:viernes/features/history/domain/history_stats.dart';
import 'package:viernes/features/reminders/domain/entities/reminder_enums.dart';
import 'package:viernes/features/reminders/domain/entities/reminder_event.dart';

ReminderEvent _event(
  DateTime at, {
  ReminderEventType type = ReminderEventType.completed,
  bool? onTime = true,
}) => ReminderEvent(
  reminderId: 'r',
  reminderTitle: 'Tarea',
  type: type,
  occurredAt: at,
  onTime: type == ReminderEventType.completed ? onTime : null,
);

void main() {
  // Jueves 1 de octubre de 2026.
  final now = DateTime(2026, 10, 1, 18);

  test('sin eventos todo es cero', () {
    final stats = HistoryStats.from(const [], now);
    expect(stats.totalCompleted, 0);
    expect(stats.currentStreak, 0);
    expect(stats.bestStreak, 0);
    expect(stats.onTimeRate, isNull);
  });

  test('cuenta las completadas de esta semana (desde el lunes)', () {
    final stats = HistoryStats.from([
      _event(DateTime(2026, 9, 28, 9)), // lunes
      _event(DateTime(2026, 10, 1, 9)),
      _event(DateTime(2026, 9, 27, 9)), // domingo anterior
    ], now);
    expect(stats.completedThisWeek, 2);
    expect(stats.totalCompleted, 3);
  });

  test('la racha sigue viva si hoy aún no se completó nada', () {
    final stats = HistoryStats.from([
      _event(DateTime(2026, 9, 28)),
      _event(DateTime(2026, 9, 29)),
      _event(DateTime(2026, 9, 30)),
    ], now);
    expect(stats.currentStreak, 3);
  });

  test('la racha se rompe con un día vacío', () {
    final stats = HistoryStats.from([
      _event(DateTime(2026, 9, 20)),
      _event(DateTime(2026, 9, 21)),
      _event(DateTime(2026, 9, 22)),
      _event(DateTime(2026, 9, 23)),
      _event(DateTime(2026, 9, 29)),
    ], now);
    expect(stats.currentStreak, 0);
    expect(stats.bestStreak, 4);
  });

  test('varias tareas el mismo día cuentan como un día de racha', () {
    final stats = HistoryStats.from([
      _event(DateTime(2026, 10, 1, 8)),
      _event(DateTime(2026, 10, 1, 12)),
    ], now);
    expect(stats.currentStreak, 1);
  });

  test('porcentaje a tiempo y pospuestos de 30 días', () {
    final stats = HistoryStats.from([
      _event(DateTime(2026, 10, 1, 8)),
      _event(DateTime(2026, 9, 30, 8), onTime: false),
      _event(DateTime(2026, 9, 25), type: ReminderEventType.snoozed),
      _event(DateTime(2026, 8), type: ReminderEventType.snoozed),
    ], now);
    expect(stats.onTimeRate, 0.5);
    expect(stats.snoozedLast30Days, 1);
  });

  test('completados de los últimos 7 días, de hace 6 días a hoy', () {
    final stats = HistoryStats.from([
      _event(DateTime(2026, 10, 1, 8)),
      _event(DateTime(2026, 10, 1, 9)),
      _event(DateTime(2026, 9, 29)),
      _event(DateTime(2026, 9, 25)), // hace 6 días
      _event(DateTime(2026, 9, 24)), // fuera del rango
    ], now);
    expect(stats.dailyCompletions, [1, 0, 0, 0, 1, 0, 2]);
  });

  test('lo que más se pospone (al menos 2 veces)', () {
    ReminderEvent snoozed(String title, int day) => ReminderEvent(
      reminderId: title,
      reminderTitle: title,
      type: ReminderEventType.snoozed,
      occurredAt: DateTime(2026, 9, day),
    );
    final stats = HistoryStats.from([
      snoozed('Ir al gimnasio', 20),
      snoozed('Ir al gimnasio', 22),
      snoozed('Ir al gimnasio', 24),
      snoozed('Llamar al banco', 25),
      snoozed('Llamar al banco', 26),
      snoozed('Leer', 27),
    ], now);
    expect(stats.mostSnoozed, [('Ir al gimnasio', 3), ('Llamar al banco', 2)]);
  });
}
