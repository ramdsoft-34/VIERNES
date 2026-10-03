import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// Cuántas grabaciones de activación hay de cada tipo.
@immutable
class WakeSampleCounts {
  const WakeSampleCounts({this.real = 0, this.errors = 0});

  /// Dijo «Viernes» de verdad (positivos para reentrenar).
  final int real;

  /// Se activó por error (negativos difíciles).
  final int errors;

  int get total => real + errors;
}

/// Audio de cada activación de «Viernes» (2 s, WAV), guardado por el servicio
/// nativo solo con el consentimiento «Ayudar a entrenar a Viernes».
///
/// Llega como `pending_<ms>_<confianza>.wav` y la app lo etiqueta según cómo
/// terminó la conversación:
/// - `real_…`: el usuario dijo algo útil → era «Viernes».
/// - `error_…`: no dijo nada o dijo «me equivoqué» → activación falsa.
///
/// Se exportan en un .zip para `training/wake_word/train_wakeword.py`.
class WakeSampleStore {
  WakeSampleStore({Future<Directory> Function()? baseDir})
    : _baseDir = baseDir ?? getApplicationSupportDirectory;

  final Future<Directory> Function() _baseDir;

  /// Misma carpeta que `WakeWordService.SAMPLES_DIR` en Kotlin.
  static const folder = 'wake_samples';
  static const _pending = 'pending_';
  static const _real = 'real_';
  static const _error = 'error_';

  Future<Directory> _dir() async =>
      Directory(p.join((await _baseDir()).path, folder));

  Future<List<File>> _files(String prefix) async {
    final dir = await _dir();
    if (!dir.existsSync()) return const [];
    return [
      for (final entity in dir.listSync())
        if (entity is File &&
            p.basename(entity.path).startsWith(prefix) &&
            entity.path.endsWith('.wav'))
          entity,
    ];
  }

  /// Etiqueta la activación más reciente (de los últimos [within]). Las
  /// pendientes viejas se descartan: no se sabe qué fueron.
  Future<void> labelLatest({
    required bool real,
    DateTime? now,
    Duration within = const Duration(minutes: 5),
  }) async {
    final pending = await _files(_pending);
    if (pending.isEmpty) return;
    final current = now ?? DateTime.now();
    File? latest;
    var latestAt = 0;
    for (final file in pending) {
      final at = _timestamp(file);
      if (at > latestAt) {
        latestAt = at;
        latest = file;
      }
    }
    for (final file in pending) {
      final age = current.difference(
        DateTime.fromMillisecondsSinceEpoch(_timestamp(file)),
      );
      if (file == latest && age <= within) {
        final name = p.basename(file.path).substring(_pending.length);
        await file.rename(
          p.join(file.parent.path, '${real ? _real : _error}$name'),
        );
      } else if (age > within) {
        await file.delete();
      }
    }
  }

  Future<WakeSampleCounts> counts() async => WakeSampleCounts(
    real: (await _files(_real)).length,
    errors: (await _files(_error)).length,
  );

  /// Empaqueta las grabaciones etiquetadas y abre el menú de compartir.
  Future<void> exportAndShare() async {
    final files = [...await _files(_real), ...await _files(_error)];
    if (files.isEmpty) return;
    final tmp = await getTemporaryDirectory();
    final zipPath = p.join(tmp.path, 'viernes-activaciones.zip');
    final encoder = ZipFileEncoder()..create(zipPath);
    for (final file in files) {
      await encoder.addFile(file);
    }
    await encoder.close();
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(zipPath, mimeType: 'application/zip')],
        subject: 'Grabaciones de «Viernes» para reentrenar el detector',
      ),
    );
  }

  Future<void> clear() async {
    final dir = await _dir();
    if (dir.existsSync()) await dir.delete(recursive: true);
  }

  static int _timestamp(File file) {
    final parts = p.basenameWithoutExtension(file.path).split('_');
    return parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0;
  }
}
