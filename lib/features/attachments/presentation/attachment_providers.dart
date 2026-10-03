import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:viernes/app/providers.dart';
import 'package:viernes/features/attachments/application/attachment_sync.dart';
import 'package:viernes/features/attachments/data/attachment_files.dart';
import 'package:viernes/features/attachments/data/attachments_repository.dart';
import 'package:viernes/features/attachments/data/firebase_attachment_remote.dart';
import 'package:viernes/features/attachments/domain/attachment.dart';

final attachmentsRepositoryProvider = Provider<AttachmentsRepository>(
  (ref) => AttachmentsRepository(
    ref.watch(appDatabaseProvider),
    now: ref.watch(clockProvider).now,
  ),
);

final attachmentFilesProvider = Provider<AttachmentFiles>(
  (ref) => const AttachmentFiles(),
);

/// Nube de adjuntos. En pruebas se sobrescribe con una falsa.
final attachmentRemoteProvider = Provider<AttachmentRemote>(
  (ref) => FirebaseAttachmentRemote(
    FirebaseFirestore.instance,
    FirebaseStorage.instance,
  ),
);

final attachmentSyncProvider = Provider<AttachmentSync>((ref) {
  final files = ref.watch(attachmentFilesProvider);
  return AttachmentSync(
    local: ref.watch(attachmentsRepositoryProvider),
    remote: ref.watch(attachmentRemoteProvider),
    prefs: ref.watch(sharedPreferencesProvider),
    localFile: (a) => files.fileFor(a.id, a.kind),
  );
});

final StreamProviderFamily<List<Attachment>, String> attachmentsProvider =
    StreamProvider.autoDispose.family<List<Attachment>, String>(
      (ref, reminderId) =>
          ref.watch(attachmentsRepositoryProvider).watchFor(reminderId),
    );

/// Ids de los recordatorios con adjuntos (para el ícono de clip).
final StreamProvider<Set<String>> remindersWithAttachmentsProvider =
    StreamProvider.autoDispose<Set<String>>(
      (ref) => ref.watch(attachmentsRepositoryProvider).watchReminderIds(),
    );
