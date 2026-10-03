import 'dart:io';
import 'dart:isolate';

import 'package:archive/archive_io.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Modelo de voz que necesita el detector de "Viernes".
abstract interface class WakeModelManager {
  /// Carpeta del modelo si está instalado.
  Future<String?> installedPath();

  /// Descarga e instala el modelo. [onProgress] recibe valores de 0 a 1.
  Future<String> install({ValueChanged<double>? onProgress});

  Future<void> remove();
}

/// Modelo pequeño de Vosk en español (~38 MB, sin internet una vez
/// descargado). Se descarga dentro de la app para no aumentar el APK.
class VoskModelManager implements WakeModelManager {
  VoskModelManager({HttpClient Function()? httpClient})
    : _httpClient = httpClient ?? HttpClient.new;

  static const String modelName = 'vosk-model-small-es-0.42';
  static final Uri modelUrl = Uri.parse(
    'https://alphacephei.com/vosk/models/$modelName.zip',
  );
  static const int approximateBytes = 39 * 1024 * 1024;

  final HttpClient Function() _httpClient;

  Future<Directory> _baseDir() async {
    final support = await getApplicationSupportDirectory();
    return Directory(p.join(support.path, 'wake_word'));
  }

  @override
  Future<String?> installedPath() async {
    final dir = p.join((await _baseDir()).path, modelName);
    // Archivo principal del modelo acústico: si existe, la extracción terminó.
    final marker = File(p.join(dir, 'am', 'final.mdl'));
    return marker.existsSync() ? dir : null;
  }

  @override
  Future<String> install({ValueChanged<double>? onProgress}) async {
    final existing = await installedPath();
    if (existing != null) return existing;

    final base = await _baseDir();
    await base.create(recursive: true);
    final zip = File(p.join(base.path, '$modelName.zip'));
    final partial = File('${zip.path}.part');

    final client = _httpClient();
    try {
      final request = await client.getUrl(modelUrl);
      final response = await request.close();
      if (response.statusCode != HttpStatus.ok) {
        throw HttpException('Respuesta ${response.statusCode}', uri: modelUrl);
      }
      final total = response.contentLength > 0
          ? response.contentLength
          : approximateBytes;
      final sink = partial.openWrite();
      var received = 0;
      await for (final chunk in response) {
        sink.add(chunk);
        received += chunk.length;
        onProgress?.call((received / total).clamp(0, 0.95));
      }
      await sink.close();
      await partial.rename(zip.path);
    } finally {
      client.close();
    }

    // Descomprimir fuera del hilo de la interfaz.
    final zipPath = zip.path;
    final outPath = base.path;
    await Isolate.run(() => extractFileToDisk(zipPath, outPath));
    await zip.delete();
    onProgress?.call(1);

    final installed = await installedPath();
    if (installed == null) {
      throw const FileSystemException('El modelo descargado está incompleto');
    }
    return installed;
  }

  @override
  Future<void> remove() async {
    final base = await _baseDir();
    if (base.existsSync()) await base.delete(recursive: true);
  }
}

/// Detector propio de «Viernes» que viene dentro del APK (~1,5 MB, sin
/// descarga). Si esta versión no lo trae, usa el modelo de respaldo.
class BundledWakeModelManager implements WakeModelManager {
  BundledWakeModelManager({
    required this._available,
    required this._fallback,
  });

  /// Ruta que el servicio nativo entiende como «modelo en assets».
  static const assetPath = 'asset:wakeword';

  final Future<bool> Function() _available;
  final WakeModelManager _fallback;

  @override
  Future<String?> installedPath() async =>
      await _available() ? assetPath : _fallback.installedPath();

  @override
  Future<String> install({ValueChanged<double>? onProgress}) async =>
      await _available()
      ? assetPath
      : _fallback.install(onProgress: onProgress);

  @override
  Future<void> remove() => _fallback.remove();
}
