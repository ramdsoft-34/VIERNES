import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:viernes/ai/nlu/es/spanish_text.dart';
import 'package:viernes/ai/speech/speech_recognizer.dart';
import 'package:viernes/core/logging/app_logger.dart';

/// Reconocimiento de voz del sistema Android (paquete `speech_to_text`).
class AndroidSpeechRecognizer implements SpeechRecognizer {
  AndroidSpeechRecognizer([SpeechToText? engine])
    : _engine = engine ?? SpeechToText();

  final SpeechToText _engine;

  /// Preferencia de idioma: español de Colombia y, si no existe, cualquier
  /// variante de español.
  static const _preferredLocales = ['es_CO', 'es_419', 'es_US', 'es_MX'];

  String? _localeId;
  Completer<SpeechResult>? _pending;
  String _lastWords = '';
  bool _permissionDenied = false;

  @override
  Future<SpeechAvailability> initialize() async {
    if (_engine.isAvailable) return SpeechAvailability.available;
    try {
      final ok = await _engine.initialize(
        onError: _onError,
        onStatus: _onStatus,
      );
      if (!ok) {
        return _permissionDenied
            ? SpeechAvailability.permissionDenied
            : SpeechAvailability.unavailable;
      }
      _localeId = await _pickLocale();
      return SpeechAvailability.available;
    } on Object catch (error, stack) {
      AppLogger.error(
        'No se pudo iniciar el reconocimiento',
        error: error,
        stackTrace: stack,
      );
      return SpeechAvailability.unavailable;
    }
  }

  Future<String?> _pickLocale() async {
    final locales = await _engine.locales();
    final ids = locales.map((l) => l.localeId.replaceAll('-', '_')).toList();
    for (final preferred in _preferredLocales) {
      if (ids.contains(preferred)) return preferred;
    }
    return ids.where((id) => id.startsWith('es')).firstOrNull;
  }

  /// Frases que terminan en «que», «de», «tengo que»…: el reconocedor de
  /// Android corta en la primera pausa aunque la persona no haya terminado.
  static final _unfinished = RegExp(
    r'\b(?:que|de|del|a|al|para|el|la|los|las|un|una|y|e|o|con|en|por|mi|'
    'mis|tu|tus|su|sus|tengo|debo|hay|recuerdame|recordarme|recordando|'
    r'avisame|cuando|como|porque|pero|si)[\s,.]*$',
  );

  static const _maxContinuations = 2;

  @override
  Future<SpeechResult> listen({
    ValueChanged<String>? onPartial,
    Duration silence = const Duration(seconds: 3),
    Duration maxDuration = const Duration(seconds: 25),
  }) async {
    final started = DateTime.now();
    var result = await _listenOnce(onPartial, silence, maxDuration);
    for (var i = 0; i < _maxContinuations; i++) {
      final heard = result;
      if (heard is! SpeechHeard) break;
      if (!_unfinished.hasMatch(SpanishText.fold(heard.text))) break;
      final left = maxDuration - DateTime.now().difference(started);
      if (left < const Duration(seconds: 3)) break;
      // Sigue escuchando y une lo que falte a lo ya dicho.
      final more = await _listenOnce(
        onPartial == null ? null : (p) => onPartial('${heard.text} $p'),
        silence,
        left,
      );
      switch (more) {
        case SpeechHeard(:final text):
          result = SpeechHeard('${heard.text} $text');
        case SpeechCancelled():
          return more;
        case SpeechSilence() || SpeechFailure():
          return heard;
      }
    }
    return result;
  }

  Future<SpeechResult> _listenOnce(
    ValueChanged<String>? onPartial,
    Duration silence,
    Duration maxDuration,
  ) async {
    await cancel();
    final completer = _pending = Completer<SpeechResult>();
    _lastWords = '';
    try {
      await _engine.listen(
        onResult: (result) {
          _lastWords = result.recognizedWords;
          onPartial?.call(_lastWords);
          if (result.finalResult) _finish(_heardOrSilence());
        },
        listenOptions: SpeechListenOptions(
          localeId: _localeId,
          listenFor: maxDuration,
          pauseFor: silence,
          cancelOnError: true,
          autoPunctuation: true,
          // Frases largas: aguanta mejor las pausas al pensar.
          listenMode: ListenMode.dictation,
        ),
      );
    } on Object catch (error) {
      _finish(SpeechFailure('$error'));
    }
    return completer.future;
  }

  @override
  Future<void> cancel() async {
    _finish(const SpeechCancelled());
    if (_engine.isListening) await _engine.cancel();
  }

  SpeechResult _heardOrSilence() => _lastWords.trim().isEmpty
      ? const SpeechSilence()
      : SpeechHeard(_lastWords.trim());

  void _finish(SpeechResult result) {
    final pending = _pending;
    if (pending != null && !pending.isCompleted) pending.complete(result);
    _pending = null;
  }

  void _onStatus(String status) {
    if (status == SpeechToText.doneStatus ||
        status == SpeechToText.notListeningStatus) {
      // Si terminó sin un resultado final, decide con lo último que oyó.
      // Se compara la escucha pendiente para ignorar avisos tardíos de una
      // escucha anterior ya cancelada.
      final pending = _pending;
      Future<void>.delayed(const Duration(milliseconds: 400), () {
        if (identical(pending, _pending) && !_engine.isListening) {
          _finish(_heardOrSilence());
        }
      });
    }
  }

  void _onError(SpeechRecognitionError error) {
    AppLogger.info('Reconocimiento: ${error.errorMsg}', tag: 'voz');
    switch (error.errorMsg) {
      case 'error_no_match' || 'error_speech_timeout':
        _finish(_heardOrSilence());
      case 'error_insufficient_permissions' || 'error_permission':
        _permissionDenied = true;
        _finish(const SpeechFailure('permission'));
      default:
        if (error.permanent) _finish(SpeechFailure(error.errorMsg));
    }
  }
}
