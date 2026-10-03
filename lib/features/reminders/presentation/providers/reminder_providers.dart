import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:viernes/app/providers.dart';
import 'package:viernes/features/alerts/application/scheduling_reminder_repository.dart';
import 'package:viernes/features/alerts/presentation/alert_providers.dart';
import 'package:viernes/features/reminders/data/drift_reminder_repository.dart';
import 'package:viernes/features/reminders/domain/entities/reminder.dart';
import 'package:viernes/features/reminders/domain/entities/reminder_enums.dart';
import 'package:viernes/features/reminders/domain/repositories/reminder_repository.dart';
import 'package:viernes/features/reminders/domain/usecases/complete_reminder.dart';
import 'package:viernes/features/reminders/domain/usecases/create_reminder.dart';
import 'package:viernes/features/reminders/domain/usecases/delete_reminder.dart';
import 'package:viernes/features/reminders/domain/usecases/move_overdue_to_tomorrow.dart';
import 'package:viernes/features/reminders/domain/usecases/reopen_reminder.dart';
import 'package:viernes/features/reminders/domain/usecases/snooze_reminder.dart';
import 'package:viernes/features/reminders/domain/usecases/update_reminder.dart';

/// Solo la base local, sin efectos (para leer la agenda completa).
final localReminderRepositoryProvider = Provider<ReminderRepository>(
  (ref) => DriftReminderRepository(ref.watch(appDatabaseProvider)),
);

/// Repositorio de la app: base local + reprogramación automática de avisos,
/// resúmenes y widget.
final reminderRepositoryProvider = Provider<ReminderRepository>(
  (ref) => SchedulingReminderRepository(
    ref.watch(localReminderRepositoryProvider),
    ref.watch(reminderAlertSyncProvider),
    onChanged: ref.watch(agendaSyncProvider).refresh,
  ),
);

// Casos de uso

final moveOverdueToTomorrowProvider = Provider<MoveOverdueToTomorrow>(
  (ref) => MoveOverdueToTomorrow(
    ref.watch(reminderRepositoryProvider),
    ref.watch(clockProvider),
  ),
);

final createReminderProvider = Provider<CreateReminder>(
  (ref) => CreateReminder(
    ref.watch(reminderRepositoryProvider),
    ref.watch(clockProvider),
    ref.watch(idGeneratorProvider),
  ),
);

final updateReminderProvider = Provider<UpdateReminder>(
  (ref) => UpdateReminder(
    ref.watch(reminderRepositoryProvider),
    ref.watch(clockProvider),
  ),
);

final completeReminderProvider = Provider<CompleteReminder>(
  (ref) => CompleteReminder(
    ref.watch(reminderRepositoryProvider),
    ref.watch(clockProvider),
  ),
);

final snoozeReminderProvider = Provider<SnoozeReminder>(
  (ref) => SnoozeReminder(
    ref.watch(reminderRepositoryProvider),
    ref.watch(clockProvider),
  ),
);

final reopenReminderProvider = Provider<ReopenReminder>(
  (ref) => ReopenReminder(
    ref.watch(reminderRepositoryProvider),
    ref.watch(clockProvider),
  ),
);

final deleteReminderProvider = Provider<DeleteReminder>(
  (ref) => DeleteReminder(
    ref.watch(reminderRepositoryProvider),
    ref.watch(clockProvider),
  ),
);

final restoreReminderProvider = Provider<RestoreReminder>(
  (ref) => RestoreReminder(
    ref.watch(reminderRepositoryProvider),
    ref.watch(clockProvider),
  ),
);

// Consultas

/// Pendientes y pospuestos, por próximo aviso.
final activeRemindersProvider = StreamProvider<List<Reminder>>(
  (ref) => ref.watch(reminderRepositoryProvider).watchByStatus({
    ReminderStatus.pending,
    ReminderStatus.snoozed,
  }),
);

final StreamProviderFamily<List<Reminder>, ReminderStatus>
remindersByStatusProvider = StreamProvider.autoDispose
    .family<List<Reminder>, ReminderStatus>(
      (ref, status) =>
          ref.watch(reminderRepositoryProvider).watchByStatus({status}),
    );

final StreamProvider<List<Reminder>> allRemindersProvider =
    StreamProvider.autoDispose<List<Reminder>>(
      (ref) => ref
          .watch(reminderRepositoryProvider)
          .watchByStatus(ReminderStatus.values.toSet()),
    );

final StreamProviderFamily<Reminder?, String> reminderByIdProvider =
    StreamProvider.autoDispose.family<Reminder?, String>(
      (ref, id) => ref.watch(reminderRepositoryProvider).watchById(id),
    );
