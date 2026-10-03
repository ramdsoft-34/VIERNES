import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:viernes/core/utils/enum_x.dart';
import 'package:viernes/features/attachments/application/attachment_sync.dart';
import 'package:viernes/features/attachments/domain/attachment.dart';

/// Adjuntos en Firebase:
///
/// ```text
/// Storage:   users/{uid}/attachments/{id}.jpg|m4a   el archivo
/// Firestore: users/{uid}/attachments/{id}           sus datos
/// ```
///
/// Las reglas (`firebase/storage.rules`) solo dejan a cada usuario leer y
/// escribir sus archivos.
class FirebaseAttachmentRemote implements AttachmentRemote {
  FirebaseAttachmentRemote(this._firestore, this._storage);

  final FirebaseFirestore _firestore;
  final FirebaseStorage _storage;

  static const _serverUpdatedAt = 'serverUpdatedAt';
  static const _overlap = Duration(minutes: 2);

  CollectionReference<Map<String, dynamic>> _meta(String uid) =>
      _firestore.collection('users').doc(uid).collection('attachments');

  @override
  Future<String> upload(String uid, Attachment a, File file) async {
    final path = 'users/$uid/attachments/${a.id}.${a.extension}';
    await _storage
        .ref(path)
        .putFile(
          file,
          SettableMetadata(
            contentType: a.kind == AttachmentKind.photo
                ? 'image/jpeg'
                : 'audio/mp4',
          ),
        );
    return path;
  }

  @override
  Future<void> saveMeta(String uid, Attachment a) => _meta(uid).doc(a.id).set({
    'reminderId': a.reminderId,
    'kind': a.kind.name,
    'remotePath': a.remotePath,
    'durationMs': a.duration?.inMilliseconds,
    'createdAt': Timestamp.fromDate(a.createdAt),
    'deleted': false,
    _serverUpdatedAt: FieldValue.serverTimestamp(),
  });

  @override
  Future<void> delete(String uid, String id) async {
    final doc = await _meta(uid).doc(id).get();
    final remotePath = doc.data()?['remotePath'] as String?;
    if (remotePath != null) {
      try {
        await _storage.ref(remotePath).delete();
      } on FirebaseException catch (error) {
        if (error.code != 'object-not-found') rethrow;
      }
    }
    await _meta(uid).doc(id).set({
      'deleted': true,
      _serverUpdatedAt: FieldValue.serverTimestamp(),
    });
  }

  @override
  Future<RemoteAttachments> pull(String uid, {DateTime? since}) async {
    Query<Map<String, dynamic>> query = _meta(uid);
    if (since != null) {
      query = query.where(
        _serverUpdatedAt,
        isGreaterThan: Timestamp.fromDate(since.subtract(_overlap)),
      );
    }
    final snapshot = await query.get(const GetOptions(source: Source.server));
    DateTime? cursor;
    final items = <RemoteAttachment>[];
    for (final doc in snapshot.docs) {
      final d = doc.data();
      final at = (d[_serverUpdatedAt] as Timestamp?)?.toDate();
      if (at != null && (cursor == null || at.isAfter(cursor))) cursor = at;
      if (d['deleted'] == true) {
        items.add(RemoteAttachment(id: doc.id));
        continue;
      }
      items.add(
        RemoteAttachment(
          id: doc.id,
          attachment: Attachment(
            id: doc.id,
            reminderId: d['reminderId'] as String? ?? '',
            kind: enumByName(
              AttachmentKind.values,
              d['kind'] as String? ?? '',
              AttachmentKind.photo,
            ),
            remotePath: d['remotePath'] as String?,
            duration: d['durationMs'] == null
                ? null
                : Duration(milliseconds: (d['durationMs'] as num).toInt()),
            createdAt:
                (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime(1970),
          ),
        ),
      );
    }
    return RemoteAttachments(items, cursor ?? since);
  }

  @override
  Future<void> download(String remotePath, File target) async {
    await target.parent.create(recursive: true);
    await _storage.ref(remotePath).writeToFile(target);
  }
}
