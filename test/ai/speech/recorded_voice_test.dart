import 'package:flutter_test/flutter_test.dart';
import 'package:viernes/ai/speech/recorded_voice.dart';
import 'package:viernes/ai/speech/speech_recognizer.dart';

class _Tts implements Speaker {
  final said = <String>[];

  @override
  Future<void> speak(String text) async => said.add(text);

  @override
  Future<void> stop() async {}
}

void main() {
  final voice = RecordedVoice(const [
    RecordedPhrase(
      id: 66,
      text: '¿Qué quieres que te recuerde?',
      file: '066.m4a',
      take: 'V1',
      duration: Duration(milliseconds: 1500),
    ),
    RecordedPhrase(
      id: 1,
      text: 'Viernes.',
      file: '001.m4a',
      take: 'V1',
      duration: Duration(milliseconds: 800),
    ),
  ]);

  test('encuentra la frase aunque cambien tildes y mayúsculas', () {
    expect(voice.match('¿que quieres que te recuerde?')?.id, 66);
    expect(voice.match('Viernes')?.id, 1);
  });

  test('una pregunta no usa la grabación de una afirmación', () {
    expect(voice.match('¿Viernes?'), isNull);
  });

  test('sin la frase grabada, habla la voz del sistema', () async {
    final tts = _Tts();
    final speaker = RecordedVoiceSpeaker(
      fallback: tts,
      voice: Future.value(voice),
      enabled: () => true,
    );
    await speaker.speak('Listo, te aviso mañana.');
    expect(tts.said, ['Listo, te aviso mañana.']);
  });

  test('con la voz grabada apagada siempre habla el sistema', () async {
    final tts = _Tts();
    final speaker = RecordedVoiceSpeaker(
      fallback: tts,
      voice: Future.value(voice),
      enabled: () => false,
    );
    await speaker.speak('¿Qué quieres que te recuerde?');
    expect(tts.said, ['¿Qué quieres que te recuerde?']);
  });
}
