import 'package:flutter_test/flutter_test.dart';
import 'package:viernes/ai/nlu/es/spanish_alert_reply_parser.dart';

void main() {
  final now = DateTime(2026, 10, 1, 10);
  const parser = SpanishAlertReplyParser();

  test('confirmaciones de que ya se hizo', () {
    for (final text in ['Sí, ya lo hice', 'ya', 'listo', 'hecho', 'ya está']) {
      expect(parser.parse(text, now).kind, AlertReplyKind.done, reason: text);
    }
  });

  test('ya no lo necesito: deja de recordarlo', () {
    for (final text in [
      'ya no lo necesito',
      'No, ya no lo necesito',
      'cancélalo',
      'bórralo',
      'ya no hace falta',
      'ya no me lo recuerdes',
    ]) {
      expect(
        parser.parse(text, now).kind,
        AlertReplyKind.dismiss,
        reason: text,
      );
    }
    // «Ya lo hice» sigue siendo hecho, no eliminar.
    expect(parser.parse('ya lo hice', now).kind, AlertReplyKind.done);
    expect(parser.parse('ahora no', now).kind, AlertReplyKind.snooze);
  });

  test('todavía no: pospone con el tiempo de los ajustes', () {
    for (final text in ['todavía no', 'no', 'más tarde', 'después']) {
      final reply = parser.parse(text, now);
      expect(reply.kind, AlertReplyKind.snooze, reason: text);
      expect(reply.until, isNull, reason: text);
    }
  });

  test('pospone hasta el momento dicho', () {
    expect(
      parser.parse('todavía no, en 20 minutos', now).until,
      DateTime(2026, 10, 1, 10, 20),
    );
    expect(
      parser.parse('recuérdamelo a las 5 de la tarde', now).until,
      DateTime(2026, 10, 1, 17),
    );
  });

  test('no entendido', () {
    expect(parser.parse('', now).kind, AlertReplyKind.unknown);
    expect(parser.parse('mmm', now).kind, AlertReplyKind.unknown);
  });
}
