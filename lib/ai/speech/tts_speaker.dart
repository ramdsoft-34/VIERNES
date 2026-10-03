import 'package:flutter_tts/flutter_tts.dart';
import 'package:viernes/ai/speech/speech_recognizer.dart';
import 'package:viernes/core/logging/app_logger.dart';

/// Voz de Viernes con el motor de texto a voz del sistema.
class TtsSpeaker implements Speaker {
  TtsSpeaker([FlutterTts? tts]) : _tts = tts ?? FlutterTts();

  final FlutterTts _tts;
  bool _configured = false;

  static const _languages = ['es-CO', 'es-US', 'es-MX', 'es-ES'];

  Future<void> _configure() async {
    if (_configured) return;
    _configured = true;
    try {
      await _tts.awaitSpeakCompletion(true);
      for (final language in _languages) {
        final available = await _tts.isLanguageAvailable(language);
        if (available == true) {
          await _tts.setLanguage(language);
          break;
        }
      }
      await _tts.setSpeechRate(0.5);
    } on Object catch (error) {
      AppLogger.error('No se pudo configurar la voz', error: error);
    }
  }

  @override
  Future<void> speak(String text) async {
    await _configure();
    try {
      await _tts.speak(text);
    } on Object catch (error) {
      AppLogger.error('No se pudo hablar', error: error);
    }
  }

  @override
  Future<void> stop() async {
    try {
      await _tts.stop();
    } on Object catch (_) {
      // Detener algo que no está sonando no es un error.
    }
  }
}
