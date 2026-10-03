import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:viernes/core/cloud/cloud.dart';
import 'package:viernes/core/logging/app_logger.dart';
import 'package:viernes/features/attachments/data/attachments_repository.dart';
import 'package:viernes/features/attachments/domain/attachment.dart';

/// Un adjunto como está en la cuenta. [attachment] es nulo si se borró.
@immutable
class RemoteAttachment {
  const RemoteAttachment({required this.id, this.attachment});

  final String id;
  final Attachment? attachment;
}

/// Cambios de adjuntos en la cuenta desde la última descarga.
@immutable
class RemoteAttachments {
  const RemoteAttachments(this.items, this.cursor);

  final List<RemoteAttachment> items;
  final DateTime? cursor;
}

/// Archivos y datos de los adjuntos en la nube (Firebase Storage + Firestore
/// `users/{uid}/attachments`).
abstract interface class AttachmentRemote {
  /// Sube el archivo y devuelve su ruta en la nube.
  Future<String> upload(String uid, Attachment attachment, File file);

  Future<void> saveMeta(String uid, Attachment attachment);

  Future<void> delete(String uid, String id);

  Future<RemoteAttachments> pull(String uid, {DateTime? since});

  Future<void> download(String remotePath, File target);
}

/// Sube, baja y borra los adjuntos de la cuenta. Va aparte de la
/// sincronización de recordatorios porque mueve archivos: si falla (p. ej.
/// sin Storage configurado), los recordatorios se sincronizan igual.
class AttachmentSync {
  AttachmentSync({
    required this._local,
    required this._remote,
    required this._prefs,
    required this._localFile,
  });

  final AttachmentsRepository _local;
  final AttachmentRemote _remote;
  final SharedPreferences _prefs;

  /// Dónde se guarda en el teléfono el archivo de un adjunto descargado.
  final Future<File> Function(Attachment attachment) _localFile;

  static String _cursorKey(String uid) => 'sync.attachmentsCursor.$uid';

  Future<void>? _running;

  Future<void> sync(String uid) =>
      _running ??= _sync(uid).whenComplete(() => _running = null);

  Future<void> _sync(String uid) async {
    // Borrados.
    for (final id in await _local.pendingDeletions()) {
      await _remote.delete(uid, id);
      await _local.forgetDeletion(id);
    }
    // Nuevos o cambiados.
    for (final attachment in await _local.pendingUpload()) {
      var current = attachment;
      if (current.remotePath == null) {
        final path = current.localPath;
        if (path == null || !File(path).existsSync()) {
          await _local.markUploaded(current.id);
          continue;
        }
        final remotePath = await _remote.upload(uid, current, File(path));
        await _local.setRemotePath(current.id, remotePath);
        current = current.copyWith(remotePath: remotePath);
      }
      await _remote.saveMeta(uid, current);
      await _local.markUploaded(current.id);
    }
    // Lo que llegó de otros teléfonos.
    final since = _readCursor(uid);
    final changes = await _remote.pull(uid, since: since);
    for (final item in changes.items) {
      final remote = item.attachment;
      if (remote == null) {
        await _local.removeRemote(item.id);
      } else if (await _local.applyRemote(remote)) {
        await ensureLocal((await _local.find(remote.id))!);
      }
    }
    final cursor = changes.cursor;
    if (cursor != null) {
      await _prefs.setInt(_cursorKey(uid), cursor.millisecondsSinceEpoch);
    }
  }

  /// Descarga el archivo si falta en el teléfono. Devuelve la ruta local o
  /// nulo si no se pudo.
  Future<String?> ensureLocal(Attachment attachment) async {
    final path = attachment.localPath;
    if (path != null && File(path).existsSync()) return path;
    final remotePath = attachment.remotePath;
    if (remotePath == null) return null;
    try {
      final file = await _localFile(attachment);
      await _remote.download(remotePath, file);
      await _local.setLocalPath(attachment.id, file.path);
      return file.path;
    } on Object catch (error) {
      if (!isOfflineError(error)) {
        AppLogger.info('No se pudo descargar el adjunto ($error)');
      }
      return null;
    }
  }

  DateTime? _readCursor(String uid) {
    final value = _prefs.getInt(_cursorKey(uid));
    return value == null ? null : DateTime.fromMillisecondsSinceEpoch(value);
  }

  Future<void> reset(String uid) => _prefs.remove(_cursorKey(uid));
}
