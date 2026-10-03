import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

part 'app_database.g.dart';

@DataClassName('ReminderRow')
@TableIndex(name: 'idx_reminders_status', columns: {#status})
@TableIndex(name: 'idx_reminders_due_at', columns: {#dueAt})
class Reminders extends Table {
  TextColumn get id => text()();
  TextColumn get title => text().withLength(min: 1, max: 200)();
  TextColumn get notes => text().nullable()();
  DateTimeColumn get dueAt => dateTime()();
  IntColumn get leadTimeMinutes => integer().withDefault(const Constant(0))();

  /// Regla codificada con `Recurrence.encode()`.
  TextColumn get recurrence => text().withDefault(const Constant(''))();
  TextColumn get priority => text()();
  TextColumn get category => text()();
  TextColumn get status => text()();
  DateTimeColumn get snoozedUntil => dateTime().nullable()();
  IntColumn get snoozeCount => integer().withDefault(const Constant(0))();
  TextColumn get source => text()();
  TextColumn get rawUtterance => text().nullable()();
  RealColumn get nluConfidence => real().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get completedAt => dateTime().nullable()();

  /// Hay cambios locales que aún no se subieron a la cuenta.
  BoolColumn get dirty => boolean().withDefault(const Constant(true))();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// Sin clave foránea a propósito: el historial se conserva aunque el
/// recordatorio se elimine.
@DataClassName('ReminderEventRow')
@TableIndex(name: 'idx_events_occurred_at', columns: {#occurredAt})
@TableIndex(name: 'idx_events_sync_id', columns: {#syncId}, unique: true)
class ReminderEvents extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get reminderId => text()();
  TextColumn get reminderTitle => text()();
  TextColumn get type => text()();
  DateTimeColumn get occurredAt => dateTime()();
  BoolColumn get onTime => boolean().nullable()();

  /// Identificador global para la nube (el `id` local cambia entre
  /// teléfonos).
  TextColumn get syncId => text().nullable()();

  /// Aún no se subió a la cuenta.
  BoolColumn get dirty => boolean().withDefault(const Constant(true))();
}

/// Borrados pendientes de subir, para que los otros teléfonos de la cuenta
/// también los eliminen.
@DataClassName('SyncTombstoneRow')
class SyncTombstones extends Table {
  /// `reminder` o `event`.
  TextColumn get entity => text()();
  TextColumn get entityId => text()();
  DateTimeColumn get deletedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {entity, entityId};
}

/// Ejemplos para entrenar el intérprete propio. Solo se guardan con el
/// consentimiento explícito del usuario y nunca salen del teléfono sin su
/// permiso.
@DataClassName('NluSampleRow')
class NluSamples extends Table {
  IntColumn get id => integer().autoIncrement()();

  /// Frases dictadas en la conversación (JSON: lista de textos).
  TextColumn get utterances => text()();

  /// Lo que entendió el intérprete con la primera frase (JSON).
  TextColumn get initialParse => text()();

  /// Lo que finalmente se guardó, ya corregido por el usuario (JSON).
  TextColumn get finalResult => text()();
  BoolColumn get corrected => boolean()();
  RealColumn get confidence => real()();
  TextColumn get interpreterVersion => text()();
  DateTimeColumn get createdAt => dateTime()();
}

@DriftDatabase(tables: [Reminders, ReminderEvents, NluSamples, SyncTombstones])
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.e);

  factory AppDatabase.open() => AppDatabase(driftDatabase(name: 'viernes'));

  /// Historial de versiones:
  /// - 1: recordatorios y eventos.
  /// - 2: ejemplos para entrenar la IA (`nlu_samples`).
  /// - 3: sincronización con la cuenta (`dirty`, `sync_id`,
  ///   `sync_tombstones`).
  @override
  int get schemaVersion => 3;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) => m.createAll(),
    onUpgrade: (m, from, to) async {
      if (from < 2) await m.createTable(nluSamples);
      if (from < 3) {
        await m.addColumn(reminders, reminders.dirty);
        await m.addColumn(reminderEvents, reminderEvents.syncId);
        await m.addColumn(reminderEvents, reminderEvents.dirty);
        // Los eventos existentes reciben su identificador global.
        await customStatement(
          'UPDATE reminder_events SET sync_id = lower(hex(randomblob(16))) '
          'WHERE sync_id IS NULL',
        );
        await m.create(idxEventsSyncId);
        await m.createTable(syncTombstones);
      }
    },
    // Los botones de la notificación escriben desde otro proceso de Flutter:
    // si la base está ocupada, esperar en vez de fallar.
    beforeOpen: (_) => customStatement('PRAGMA busy_timeout = 5000'),
  );

  /// Avisa a las consultas abiertas que los datos pudieron cambiar fuera de
  /// esta conexión (p. ej. desde la notificación con la app en segundo plano).
  void refreshAll() => markTablesUpdated(allTables);
}

/// Valores de `sync_tombstones.entity`.
abstract final class SyncEntities {
  static const reminder = 'reminder';
  static const event = 'event';
}
