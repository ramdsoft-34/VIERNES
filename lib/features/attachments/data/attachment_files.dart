import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:viernes/features/attachments/domain/attachment.dart';

/// Carpeta de la app donde viven las fotos y notas de voz.
class AttachmentFiles {
  const AttachmentFiles();

  Future<Directory> directory() async {
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(base.path, 'attachments'));
    if (!dir.existsSync()) await dir.create(recursive: true);
    return dir;
  }

  /// Archivo para el adjunto [id] del tipo [kind].
  Future<File> fileFor(String id, AttachmentKind kind) async {
    final dir = await directory();
    final ext = kind == AttachmentKind.photo ? 'jpg' : 'm4a';
    return File(p.join(dir.path, '$id.$ext'));
  }

  /// Copia una foto elegida (cámara o galería) a la carpeta de la app.
  Future<String> importPhoto(String sourcePath, String id) async {
    final target = await fileFor(id, AttachmentKind.photo);
    await File(sourcePath).copy(target.path);
    return target.path;
  }

  /// Borra todos los adjuntos del teléfono (al cerrar sesión).
  Future<void> clear() async {
    final dir = await directory();
    if (dir.existsSync()) await dir.delete(recursive: true);
  }
}
