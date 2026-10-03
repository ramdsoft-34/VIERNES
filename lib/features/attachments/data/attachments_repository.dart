import 'dart:io';

import 'package:drift/drift.dart';
import 'package:viernes/core/database/app_database.dart';
import 'package:viernes/core/utils/enum_x.dart';
import 'package:viernes/features/attachments/domain/attachment.dart';

/// Adjuntos guardados en la base local. Los archivos viven en la carpeta de
/// la app (ver `AttachmentFiles`).
class AttachmentsRepository {
  AttachmentsRepository(this._db, {DateTime Function()? now})
    : _now = now ?? DateTime.now;

  final AppDatabase _db;
  final DateTime Function() _now;

  Stream<List<Attachment>> watchFor(String reminderId) =>
      (_db.select(_db.attachments)
            ..where((a) => a.reminderId.equals(reminderId))
            ..orderBy([(a) => OrderingTerm.asc(a.createdAt)]))
          .watch()
          .map((rows) => [for (final r in rows) fromRow(r)]);

  Future<List<Attachment>> forReminder(String reminderId) =>
      watchFor(reminderId).first;

  /// Recordatorios que tienen algún adjunto (para mostrar el clip).
  Stream<Set<String>> watchReminderIds() => _db
      .customSelect(
        'SELECT DISTINCT reminder_id FROM attachments',
        readsFrom: {_db.attachments},
      )
      .watch()
      .map((rows) => {for (final r in rows) r.read<String>('reminder_id')});

  Future<Attachment?> find(String id) async {
    final row = await (_db.select(
      _db.attachments,
    )..where((a) => a.id.equals(id))).getSingleOrNull();
    return row == null ? null : fromRow(row);
  }

  Future<void> add(Attachment a) => _db
      .into(_db.attachments)
      .insertOnConflictUpdate(_companion(a, dirty: true));

  /// Borra el adjunto y su archivo; con cuenta, también se borra de la nube.
  Future<void> delete(Attachment a) async {
    await _db.transaction(() async {
      await (_db.delete(_db.attachments)..where((r) => r.id.equals(a.id))).go();
      await _db
          .into(_db.syncTombstones)
          .insertOnConflictUpdate(
            SyncTombstonesCompanion.insert(
              entity: SyncEntities.attachment,
              entityId: a.id,
              deletedAt: _now(),
            ),
          );
    });
    await deleteFile(a.localPath);
  }

  Future<void> setLocalPath(String id, String path) =>
      (_db.update(_db.attachments)..where((a) => a.id.equals(id))).write(
        AttachmentsCompanion(localPath: Value(path)),
      );

  Future<void> setRemotePath(String id, String path) =>
      (_db.update(_db.attachments)..where((a) => a.id.equals(id))).write(
        AttachmentsCompanion(remotePath: Value(path)),
      );

  // --- Sincronización --------------------------------------------------------

  Future<List<Attachment>> pendingUpload() async => [
    for (final r in await (_db.select(
      _db.attachments,
    )..where((a) => a.dirty.equals(true))).get())
      fromRow(r),
  ];

  Future<void> markUploaded(String id) =>
      (_db.update(_db.attachments)..where((a) => a.id.equals(id))).write(
        const AttachmentsCompanion(dirty: Value(false)),
      );

  /// Adjuntos borrados que falta borrar de la nube.
  Future<List<String>> pendingDeletions() async => [
    for (final t in await (_db.select(
      _db.syncTombstones,
    )..where((t) => t.entity.equals(SyncEntities.attachment))).get())
      t.entityId,
  ];

  Future<void> forgetDeletion(String id) =>
      (_db.delete(_db.syncTombstones)..where(
            (t) =>
                t.entity.equals(SyncEntities.attachment) &
                t.entityId.equals(id),
          ))
          .go();

  /// Aplica un adjunto que llegó de la cuenta (sin archivo local todavía si
  /// es nuevo). Devuelve `false` si aquí se había borrado.
  Future<bool> applyRemote(Attachment remote) async {
    final deleted =
        await (_db.select(_db.syncTombstones)..where(
              (t) =>
                  t.entity.equals(SyncEntities.attachment) &
                  t.entityId.equals(remote.id),
            ))
            .getSingleOrNull();
    if (deleted != null) return false;
    final local = await find(remote.id);
    await _db
        .into(_db.attachments)
        .insertOnConflictUpdate(
          _companion(
            remote.copyWith(localPath: local?.localPath),
            dirty: false,
          ),
        );
    return true;
  }

  /// Un adjunto se borró en otro teléfono.
  Future<void> removeRemote(String id) async {
    final local = await find(id);
    if (local == null) return;
    await (_db.delete(_db.attachments)..where((a) => a.id.equals(id))).go();
    await deleteFile(local.localPath);
  }

  /// Adjuntos de recordatorios que ya no existen (se borraron hace rato).
  Future<int> removeOrphans() async {
    final orphans = await _db
        .customSelect(
          'SELECT id FROM attachments WHERE reminder_id NOT IN '
          '(SELECT id FROM reminders)',
          readsFrom: {_db.attachments, _db.reminders},
        )
        .get();
    for (final row in orphans) {
      final a = await find(row.read<String>('id'));
      if (a != null) await delete(a);
    }
    return orphans.length;
  }

  static Future<void> deleteFile(String? path) async {
    if (path == null) return;
    try {
      final file = File(path);
      if (file.existsSync()) await file.delete();
    } on Object {
      // Si no se puede borrar, no pasa nada: queda en la carpeta de la app.
    }
  }

  static Attachment fromRow(AttachmentRow r) => Attachment(
    id: r.id,
    reminderId: r.reminderId,
    kind: enumByName(AttachmentKind.values, r.kind, AttachmentKind.photo),
    localPath: r.localPath,
    remotePath: r.remotePath,
    duration: r.durationMs == null
        ? null
        : Duration(milliseconds: r.durationMs!),
    createdAt: r.createdAt,
  );

  static AttachmentsCompanion _companion(
    Attachment a, {
    required bool dirty,
  }) => AttachmentsCompanion.insert(
    id: a.id,
    reminderId: a.reminderId,
    kind: a.kind.name,
    localPath: Value(a.localPath),
    remotePath: Value(a.remotePath),
    durationMs: Value(a.duration?.inMilliseconds),
    createdAt: a.createdAt,
    dirty: Value(dirty),
  );
}
