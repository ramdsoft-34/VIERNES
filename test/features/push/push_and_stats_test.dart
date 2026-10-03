import 'package:flutter_test/flutter_test.dart';
import 'package:viernes/ai/wake_word/wake_word_service.dart';
import 'package:viernes/features/push/push_messages.dart';

void main() {
  group('PushNotice', () {
    test('recordatorio recibido', () {
      final notice = PushNotice.from({
        'type': PushTypes.sharedReminder,
        'id': 's1',
        'title': 'Recoger el paquete',
        'fromName': 'Ana',
      })!;
      expect(notice.title, 'Ana te envió un recordatorio');
      expect(notice.body, 'Recoger el paquete');
    });

    test('«lo hizo» usa el nombre del contacto', () {
      final notice = PushNotice.from(
        {
          'type': PushTypes.sharedDone,
          'id': 's1',
          'title': 'Recoger el paquete',
          'toEmail': 'sofi@gmail.com',
        },
        nameOf: (email) => email == 'sofi@gmail.com' ? 'Sofi' : email,
      )!;
      expect(notice.title, 'Sofi lo hizo ✓');
    });

    test('asignación e invitación a listas', () {
      final assigned = PushNotice.from({
        'type': PushTypes.listAssigned,
        'listName': 'Casa',
        'itemId': 'i1',
        'text': 'Pagar el internet',
        'by': 'Ana',
      })!;
      expect(assigned.title, 'En la lista Casa te toca');
      expect(assigned.body, 'Pagar el internet (de Ana)');

      final invite = PushNotice.from({
        'type': PushTypes.listInvite,
        'listId': 'l1',
        'listName': 'Mercado',
      })!;
      expect(invite.body, 'Lista «Mercado»');
    });

    test('ignora lo desconocido o incompleto', () {
      expect(PushNotice.from({'type': 'otro'}), isNull);
      expect(PushNotice.from({'type': PushTypes.sharedReminder}), isNull);
    });
  });

  test('cifras de consumo de la escucha', () {
    final stats = WakeStats.fromMap(const {
      'listeningMs': 2 * 60 * 60 * 1000,
      'frames': 1000,
      'skipped': 700,
      'avgInferenceMs': 3.5,
      'batteryPerHour': 1.2,
      'cpuPercent': -1.0,
    });
    expect(stats.listening, const Duration(hours: 2));
    expect(stats.savedRatio, 0.7);
    expect(stats.batteryPercentPerHour, 1.2);
    // -1 = aún sin datos.
    expect(stats.cpuPercent, isNull);
  });
}
