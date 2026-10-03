import 'package:flutter_test/flutter_test.dart';
import 'package:viernes/ai/nlu/es/spanish_reply_parser.dart';
import 'package:viernes/core/utils/day_time.dart';

void main() {
  final now = DateTime(2026, 10, 1, 10);
  const parser = SpanishReplyParser();

  ReplyKind kind(String text) => parser.parse(text, now).kind;

  test('afirmaciones', () {
    for (final text in [
      'Sí',
      'si',
      'Correcto',
      'dale',
      'listo',
      'ok',
      'perfecto, gracias',
      'sí, guárdalo',
      'así está bien',
      'de una',
    ]) {
      expect(kind(text), ReplyKind.affirm, reason: text);
    }
  });

  test('negaciones sin corrección', () {
    for (final text in ['no', 'No.', 'nop', 'está mal']) {
      expect(kind(text), ReplyKind.deny, reason: text);
    }
  });

  test('cancelaciones', () {
    for (final text in ['cancela', 'olvídalo', 'no, déjalo así', 'nada']) {
      expect(kind(text), ReplyKind.cancel, reason: text);
    }
  });

  test('correcciones de hora', () {
    final reply = parser.parse('No, a las 9', now);
    expect(reply.kind, ReplyKind.correction);
    // La mañana o la noche se decide al combinarla con el día elegido.
    expect(reply.correction!.time, const DayTime(9, 0));
    expect(reply.correction!.ambiguousHour, isTrue);
    expect(reply.correction!.title, isEmpty);
  });

  test('correcciones de fecha', () {
    final reply = parser.parse('mejor el lunes', now);
    expect(reply.kind, ReplyKind.correction);
    expect(reply.correction!.date, DateTime(2026, 10, 5));
  });

  test('"sí, pero en la tarde" es una corrección', () {
    expect(kind('sí, pero en la tarde'), ReplyKind.correction);
  });

  test('"para el jueves" no es cancelar', () {
    expect(kind('para el jueves'), ReplyKind.correction);
  });

  test('texto vacío o sin sentido', () {
    expect(kind(''), ReplyKind.unknown);
    expect(kind('mmm'), ReplyKind.unknown);
  });
}
