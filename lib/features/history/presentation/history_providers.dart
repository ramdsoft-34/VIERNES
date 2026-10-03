import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:viernes/features/reminders/domain/entities/reminder_enums.dart';
import 'package:viernes/features/reminders/domain/entities/reminder_event.dart';
import 'package:viernes/features/reminders/presentation/providers/reminder_providers.dart';

/// Eventos que se muestran como actividad y alimentan las estadísticas.
const Set<ReminderEventType> historyEventTypes = {
  ReminderEventType.completed,
  ReminderEventType.snoozed,
  ReminderEventType.reopened,
  ReminderEventType.deleted,
};

final StreamProvider<List<ReminderEvent>> historyEventsProvider =
    StreamProvider.autoDispose<List<ReminderEvent>>(
      (ref) => ref
          .watch(reminderRepositoryProvider)
          .watchEvents(types: historyEventTypes),
    );
