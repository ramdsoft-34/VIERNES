import 'dart:async';

import 'package:viernes/features/reminders/domain/entities/reminder.dart';
import 'package:viernes/features/reminders/domain/entities/reminder_enums.dart';
import 'package:viernes/features/reminders/domain/entities/reminder_event.dart';
import 'package:viernes/features/reminders/domain/repositories/reminder_repository.dart';

/// Repositorio en memoria para probar casos de uso y widgets sin base de datos.
class FakeReminderRepository implements ReminderRepository {
  final Map<String, Reminder> reminders = {};
  final List<ReminderEvent> events = [];
  final _changes = StreamController<void>.broadcast();
  var _nextEventId = 1;

  Stream<T> _watch<T>(T Function() read) async* {
    yield read();
    yield* _changes.stream.map((_) => read());
  }

  void _notify() => _changes.add(null);

  @override
  Stream<List<Reminder>> watchByStatus(Set<ReminderStatus> statuses) => _watch(
    () =>
        reminders.values.where((r) => statuses.contains(r.status)).toList()
          ..sort((a, b) => a.nextTriggerAt.compareTo(b.nextTriggerAt)),
  );

  @override
  Stream<List<Reminder>> watchDueBetween(DateTime from, DateTime to) => _watch(
    () =>
        reminders.values
            .where((r) => !r.dueAt.isBefore(from) && r.dueAt.isBefore(to))
            .toList()
          ..sort((a, b) => a.dueAt.compareTo(b.dueAt)),
  );

  @override
  Stream<Reminder?> watchById(String id) => _watch(() => reminders[id]);

  @override
  Future<Reminder?> findById(String id) async => reminders[id];

  @override
  Future<void> save(Reminder reminder, {ReminderEvent? event}) async {
    reminders[reminder.id] = reminder;
    if (event != null) _addEvent(event);
    _notify();
  }

  @override
  Future<void> delete(String id, {ReminderEvent? event}) async {
    reminders.remove(id);
    if (event != null) _addEvent(event);
    _notify();
  }

  @override
  Future<void> revert(
    Reminder previous, {
    required ReminderEventType undoneEvent,
  }) async {
    reminders[previous.id] = previous;
    final index = events.lastIndexWhere(
      (e) => e.reminderId == previous.id && e.type == undoneEvent,
    );
    if (index >= 0) events.removeAt(index);
    _notify();
  }

  @override
  Stream<List<ReminderEvent>> watchEvents({
    Set<ReminderEventType>? types,
    DateTime? since,
  }) => _watch(
    () =>
        events
            .where((e) => types == null || types.contains(e.type))
            .where((e) => since == null || !e.occurredAt.isBefore(since))
            .toList()
          ..sort((a, b) => b.occurredAt.compareTo(a.occurredAt)),
  );

  void _addEvent(ReminderEvent event) => events.add(
    ReminderEvent(
      id: _nextEventId++,
      reminderId: event.reminderId,
      reminderTitle: event.reminderTitle,
      type: event.type,
      occurredAt: event.occurredAt,
      onTime: event.onTime,
    ),
  );
}
