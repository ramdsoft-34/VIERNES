import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';
import 'package:viernes/ai/nlu/es/spanish_text.dart';
import 'package:viernes/ai/speech/speech_recognizer.dart';
import 'package:viernes/core/logging/app_logger.dart';

/// Una frase grabada con la voz propia de Viernes (`assets/voice`).
@immutable
class RecordedPhrase {
  const RecordedPhrase({
    required this.id,
    required this.text,
    required this.file,
    required this.take,
    required this.duration,
  });

  factory RecordedPhrase.fromJson(Map<String, Object?> json) => RecordedPhrase(
    id: (json['id']! as num).toInt(),
    text: json['texto']! as String,
    file: json['archivo']! as String,
    take: json['toma'] as String? ?? '',
    duration: Duration(
      milliseconds: (((json['duracion'] as num?) ?? 0) * 1000).round(),
    ),
  );

  /// Número en `training/voice/guion-grabacion.md`.
  final int id;
  final String text;
  final String file;

  /// Toma elegida (V1 o V2).
  final String take;
  final Duration duration;

  String get asset => '${RecordedVoice.folder}/$file';
}

/// Frases grabadas por una persona (la voz propia de Viernes). Cuando Viernes
/// va a decir exactamente una de ellas, suena la grabación; lo demás lo dice
/// la voz del sistema.
class RecordedVoice {
  RecordedVoice(this.phrases)
    : _byKey = {for (final p in phrases) key(p.text): p};

  static const folder = 'assets/voice';

  final List<RecordedPhrase> phrases;
  final Map<String, RecordedPhrase> _byKey;

  /// Carga `assets/voice/manifest.json`. Vacía si esta compilación no trae
  /// grabaciones (no se suben al repositorio).
  static Future<RecordedVoice> load([AssetBundle? bundle]) async {
    try {
      final raw = await (bundle ?? rootBundle).loadString(
        '$folder/manifest.json',
      );
      final data = jsonDecode(raw) as Map<String, Object?>;
      final list = (data['frases'] as List? ?? const [])
          .map(
            (e) => RecordedPhrase.fromJson(Map<String, Object?>.from(e as Map)),
          )
          .toList();
      return RecordedVoice(list);
    } on Object catch (error) {
      AppLogger.info('Sin voz grabada ($error)');
      return RecordedVoice(const []);
    }
  }

  /// Misma frase aunque cambien tildes, mayúsculas o comas; pero «Viernes.»
  /// y «¿Viernes?» son distintas (cambia la entonación).
  static String key(String text) {
    final trimmed = text.trim();
    final kind = trimmed.contains('?')
        ? '?'
        : trimmed.contains('!')
        ? '!'
        : '.';
    final words = SpanishText.fold(trimmed)
        .replaceAll(RegExp('[^a-zñ0-9 ]'), ' ')
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .join(' ');
    return '$words$kind';
  }

  RecordedPhrase? match(String text) => _byKey[key(text)];

  bool get isEmpty => phrases.isEmpty;
}

/// Habla con la voz grabada si la frase existe; si no, con la del sistema.
class RecordedVoiceSpeaker implements Speaker {
  RecordedVoiceSpeaker({
    required this._fallback,
    required this._voice,
    required this._enabled,
    AudioPlayer Function()? player,
  }) : _newPlayer = player ?? AudioPlayer.new;

  final Speaker _fallback;
  final Future<RecordedVoice> _voice;
  final bool Function() _enabled;
  final AudioPlayer Function() _newPlayer;
  AudioPlayer? _player;

  @override
  Future<void> speak(String text) async {
    if (_enabled()) {
      final phrase = (await _voice).match(text);
      if (phrase != null && await play(phrase)) return;
    }
    await _fallback.speak(text);
  }

  /// Reproduce una frase grabada y espera a que termine. `false` si no se
  /// pudo (entonces habla la voz del sistema).
  Future<bool> play(RecordedPhrase phrase) async {
    try {
      final player = _player ??= _newPlayer();
      await player.stop();
      await player.setAsset(phrase.asset);
      await player.play();
      await player.processingStateStream.firstWhere(
        (s) => s == ProcessingState.completed || s == ProcessingState.idle,
      );
      return true;
    } on Object catch (error) {
      AppLogger.info('No se pudo reproducir la frase ${phrase.id} ($error)');
      return false;
    }
  }

  @override
  Future<void> stop() async {
    await _player?.stop();
    await _fallback.stop();
  }
}
