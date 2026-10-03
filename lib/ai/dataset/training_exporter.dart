import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:viernes/ai/dataset/training_data_repository.dart';
import 'package:viernes/ai/dataset/training_sample.dart';

/// Exporta las frases guardadas como JSONL (una conversación por línea),
/// el formato que usan los scripts de `training/nlu/`.
class TrainingExporter {
  const TrainingExporter(this._repository);

  final TrainingDataRepository _repository;

  /// Convierte los ejemplos en texto JSONL.
  static String toJsonl(Iterable<TrainingSample> samples) =>
      samples.map((s) => jsonEncode(s.toJson())).join('\n');

  /// Escribe el archivo y abre el menú de compartir del teléfono. El usuario
  /// decide a dónde enviarlo; la app nunca lo sube por su cuenta.
  Future<void> exportAndShare(DateTime now) async {
    final samples = await _repository.all();
    final dir = await getTemporaryDirectory();
    final stamp =
        '${now.year}${_two(now.month)}${_two(now.day)}-'
        '${_two(now.hour)}${_two(now.minute)}';
    final file = File(p.join(dir.path, 'viernes-frases-$stamp.jsonl'));
    await file.writeAsString(toJsonl(samples));
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path, mimeType: 'application/jsonl')],
        subject: 'Frases de entrenamiento de Viernes',
      ),
    );
  }

  static String _two(int value) => value.toString().padLeft(2, '0');
}
