import 'package:flutter_test/flutter_test.dart';
import 'package:viernes/ai/nlu/es/spanish_cancel_detector.dart';

void main() {
  group('cancela', () {
    for (final phrase in [
      'cancela',
      'Cancélalo',
      'olvídalo',
      'Olvídalo, gracias',
      'déjalo así',
      'nada',
      'No, nada',
      'ya no quiero',
      'Ya no lo quiero',
      'ya no lo necesito',
      'Viernes, ya no lo necesito',
      'no necesito nada',
      'ya no hace falta',
      'no importa',
      'me equivoqué',
      'perdón, me equivoqué',
      'fue sin querer',
      'te llamé sin querer',
      'no te estaba hablando',
      'falsa alarma',
      'no era nada',
      'no, gracias',
      'mejor no',
      'ahora no',
      'después te digo',
      'ya no, gracias',
      'para',
      'basta',
      'chao',
    ]) {
      test(
        phrase,
        () => expect(SpanishCancelDetector.isCancel(phrase), isTrue),
      );
    }
  });

  group('no cancela', () {
    for (final phrase in [
      'no',
      'sí',
      'ya',
      'listo',
      'mejor el jueves',
      'no, a las 9',
      'para mañana',
      'recuérdame que ya no quiero café',
      'ya no quiero ir al gimnasio los lunes',
      'mañana a las 8 correr',
      'nada de dulces el lunes',
      '',
    ]) {
      test(
        '"$phrase"',
        () => expect(SpanishCancelDetector.isCancel(phrase), isFalse),
      );
    }
  });
}
