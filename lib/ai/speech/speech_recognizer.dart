import 'package:flutter/foundation.dart';

enum SpeechAvailability { available, permissionDenied, unavailable }

/// Resultado de escuchar una frase.
@immutable
sealed class SpeechResult {
  const SpeechResult();
}

/// Se reconoció texto.
final class SpeechHeard extends SpeechResult {
  const SpeechHeard(this.text);

  final String text;
}

/// El usuario no dijo nada (o no se entendió) antes del tiempo límite.
final class SpeechSilence extends SpeechResult {
  const SpeechSilence();
}

/// Se canceló la escucha (p. ej. el usuario tocó un botón).
final class SpeechCancelled extends SpeechResult {
  const SpeechCancelled();
}

final class SpeechFailure extends SpeechResult {
  const SpeechFailure(this.message);

  final String message;
}

/// Voz a texto. Hoy usa el reconocedor de Android; más adelante puede ser un
/// modelo local (Whisper/Vosk) sin tocar el resto de la app.
abstract interface class SpeechRecognizer {
  Future<SpeechAvailability> initialize();

  /// Escucha una frase. Termina tras [silence] sin voz o al llegar a
  /// [maxDuration]. [onPartial] recibe el texto a medida que se reconoce.
  Future<SpeechResult> listen({
    ValueChanged<String>? onPartial,
    Duration silence = const Duration(seconds: 3),
    Duration maxDuration = const Duration(seconds: 25),
  });

  /// Detiene la escucha y descarta el resultado.
  Future<void> cancel();
}

/// Texto a voz.
abstract interface class Speaker {
  /// Habla y termina cuando acaba de decir [text].
  Future<void> speak(String text);

  Future<void> stop();
}
