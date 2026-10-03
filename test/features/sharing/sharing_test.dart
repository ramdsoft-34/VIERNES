import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:viernes/ai/nlu/es/spanish_share_parser.dart';
import 'package:viernes/core/error/result.dart';
import 'package:viernes/features/reminders/domain/entities/reminder.dart';
import 'package:viernes/features/reminders/domain/entities/reminder_draft.dart';
import 'package:viernes/features/reminders/domain/entities/reminder_enums.dart';
import 'package:viernes/features/sharing/application/shared_inbox.dart';
import 'package:viernes/features/sharing/data/contacts_repository.dart';
import 'package:viernes/features/sharing/domain/sharing_models.dart';

import '../../helpers/fake_sharing.dart';

void main() {
  group('SpanishShareParser', () {
    test('recuérdale a alguien', () {
      expect(
        SpanishShareParser.parseShare(
          'Recuérdale a Sofi recoger el paquete mañana a las 5',
        )?.afterTo,
        'Sofi recoger el paquete mañana a las 5',
      );
      expect(
        SpanishShareParser.parseShare(
          'Viernes, dile a mi mamá que compre pan',
        )?.afterTo,
        'mi mamá que compre pan',
      );
      expect(SpanishShareParser.parseShare('recuérdame pagar la luz'), isNull);
    });

    test('agregar a una lista', () {
      final r = SpanishShareParser.parseListAdd(
        'Agrega leche, pan y huevos a la lista del mercado',
      )!;
      expect(r.items, ['Leche', 'Pan', 'Huevos']);
      expect(r.listName, 'mercado');

      final b = SpanishShareParser.parseListAdd(
        'anota arreglar la llave en la lista de la casa',
      )!;
      expect(b.items, ['Arreglar la llave']);
      expect(b.listName, 'casa');
    });

    test('leer una lista', () {
      expect(
        SpanishShareParser.parseListRead('¿Qué hay en la lista del mercado?'),
        'mercado',
      );
      expect(
        SpanishShareParser.parseListRead('léeme la lista de la casa'),
        'casa',
      );
    });

    test('separa el contacto del resto de la frase', () {
      const contacts = [
        Contact(name: 'Sofi', email: 'sofi@gmail.com'),
        Contact(name: 'Mamá', email: 'mama@gmail.com'),
      ];
      final a = matchContactPrefix('Sofi recoger el paquete', contacts)!;
      expect(a.contact.name, 'Sofi');
      expect(a.rest, 'recoger el paquete');
      final b = matchContactPrefix('mi mamá que compre pan', contacts)!;
      expect(b.contact.name, 'Mamá');
      expect(b.rest, 'que compre pan');
      expect(matchContactPrefix('Juan que llame', contacts), isNull);
    });
  });

  group('SharedInbox', () {
    late FakeSharingRepository remote;
    late FakeInfoNotifier notifier;
    late SharedInbox inbox;
    late List<ReminderDraft> created;

    SharedReminder incoming({String id = 's1'}) => SharedReminder(
      id: id,
      fromUid: 'ana',
      fromName: 'Ana',
      fromEmail: 'ana@gmail.com',
      toEmail: 'sofi@gmail.com',
      title: 'Recoger el paquete',
      dueAt: DateTime(2026, 10, 4, 17),
      createdAt: DateTime(2026, 10, 3),
    );

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      remote = FakeSharingRepository();
      notifier = FakeInfoNotifier();
      created = [];
      inbox = SharedInbox(
        remote: remote,
        create: (draft) async {
          created.add(draft);
          return Result.ok(
            Reminder(
              id: 'local-${created.length}',
              title: draft.title,
              dueAt: draft.dueAt,
              createdAt: DateTime(2026, 10, 3),
              updatedAt: DateTime(2026, 10, 3),
              source: draft.source,
            ),
          );
        },
        links: SharedLinks(prefs),
        notifier: notifier,
        now: () => DateTime(2026, 10, 4, 18),
      );
    });

    test('lo recibido llega a la agenda una sola vez', () async {
      await remote.send(incoming());

      await inbox.accept([incoming()]);
      await inbox.accept([incoming()]);

      expect(created, hasLength(1));
      expect(created.single.source, ReminderSource.shared);
      expect(created.single.notes, 'Te lo envió Ana');
      expect(remote.shared['s1']!.status, SharedStatus.accepted);
      expect(notifier.shown.single.$1, contains('Ana'));
    });

    test('al completarlo aquí se avisa a quien lo envió', () async {
      await remote.send(incoming());
      await inbox.accept([incoming()]);
      final done = Reminder(
        id: 'local-1',
        title: 'Recoger el paquete',
        dueAt: DateTime(2026, 10, 4, 17),
        createdAt: DateTime(2026, 10, 3),
        updatedAt: DateTime(2026, 10, 4),
        status: ReminderStatus.completed,
        completedAt: DateTime(2026, 10, 4, 16),
      );

      await inbox.reportCompleted([done]);

      expect(remote.shared['s1']!.status, SharedStatus.done);
      expect(remote.shared['s1']!.doneAt, DateTime(2026, 10, 4, 16));
    });

    test('quien envió recibe aviso cuando lo hacen (sin repetir)', () async {
      final doneItem = incoming().copyWith(status: SharedStatus.done);
      const contacts = [Contact(name: 'Sofi', email: 'sofi@gmail.com')];

      await inbox.notifyDone([doneItem], contacts);
      await inbox.notifyDone([doneItem], contacts);

      expect(notifier.shown.single.$1, 'Sofi lo hizo ✓');
    });

    test('al abrir la app no repite avisos viejos', () async {
      final doneItem = incoming().copyWith(status: SharedStatus.done);

      await inbox.notifyDone([doneItem], const [], silent: true);
      await inbox.notifyDone([doneItem], const []);

      expect(notifier.shown, isEmpty);
    });
  });
}
