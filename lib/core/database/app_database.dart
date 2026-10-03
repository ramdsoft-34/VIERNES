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

/// Lugares guardados por el usuario (Casa, Trabajo, Supermercado…).
@DataClassName('PlaceRow')
class Places extends Table {
  TextColumn get id => text()();
  TextColumn get name => text().withLength(min: 1, max: 60)();
  RealColumn get latitude => real()();
  RealColumn get longitude => real()();
  RealColumn get radiusMeters => real().withDefault(const Constant(150))();
  DateTimeColumn get createdAt => dateTime()();

  /// Último cambio (para resolver conflictos entre teléfonos).
  DateTimeColumn get updatedAt => dateTime().nullable()();

  /// Hay cambios que aún no se subieron a la cuenta.
  BoolColumn get dirty => boolean().withDefault(const Constant(true))();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// «Recuérdame comprar leche cuando llegue a casa».
@DataClassName('LocationReminderRow')
class LocationReminders extends Table {
  TextColumn get id => text()();
  TextColumn get title => text().withLength(min: 1, max: 200)();
  TextColumn get placeId => text()();

  /// Verdadero: al llegar; falso: al salir.
  BoolColumn get onArrive => boolean().withDefault(const Constant(true))();
  BoolColumn get done => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get completedAt => dateTime().nullable()();
  DateTimeColumn get updatedAt => dateTime().nullable()();
  BoolColumn get dirty => boolean().withDefault(const Constant(true))();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// Foto o nota de voz de un recordatorio. El archivo vive en el teléfono
/// ([localPath]) y, con cuenta, también en la nube ([remotePath]).
@DataClassName('AttachmentRow')
@TableIndex(name: 'idx_attachments_reminder', columns: {#reminderId})
class Attachments extends Table {
  TextColumn get id => text()();
  TextColumn get reminderId => text()();

  /// `photo` o `audio`.
  TextColumn get kind => text()();
  TextColumn get localPath => text().nullable()();
  TextColumn get remotePath => text().nullable()();

  /// Duración de la nota de voz.
  IntColumn get durationMs => integer().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  BoolColumn get dirty => boolean().withDefault(const Constant(true))();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DriftDatabase(
  tables: [
    Reminders,
    ReminderEvents,
    NluSamples,
    SyncTombstones,
    Places,
    LocationReminders,
    Attachments,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.e);

  factory AppDatabase.open() => AppDatabase(driftDatabase(name: 'viernes'));

  /// Historial de versiones:
  /// - 1: recordatorios y eventos.
  /// - 2: ejemplos para entrenar la IA (`nlu_samples`).
  /// - 3: sincronización con la cuenta (`dirty`, `sync_id`,
  ///   `sync_tombstones`).
  /// - 4: recordatorios por ubicación (`places`, `location_reminders`).
  /// - 5: lugares sincronizados con la cuenta (`dirty`, `updated_at`) y
  ///   adjuntos (`attachments`).
  @override
  int get schemaVersion => 5;

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
      if (from < 4) {
        await m.createTable(places);
        await m.createTable(locationReminders);
      } else if (from < 5) {
        await m.addColumn(places, places.updatedAt);
        await m.addColumn(places, places.dirty);
        await m.addColumn(locationReminders, locationReminders.updatedAt);
        await m.addColumn(locationReminders, locationReminders.dirty);
      }
      if (from < 5) await m.createTable(attachments);
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
  static const place = 'place';
  static const locationReminder = 'location_reminder';
  static const attachment = 'attachment';
}
