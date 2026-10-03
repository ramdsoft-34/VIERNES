import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:viernes/ai/nlu/es/spanish_share_parser.dart';
import 'package:viernes/features/sharing/data/offline_sharing_repository.dart';
import 'package:viernes/features/sharing/domain/sharing_models.dart';

import '../../helpers/fake_sharing.dart';

/// Nube que puede quedarse sin internet.
class FlakySharing extends FakeSharingRepository {
  bool offline = false;

  Future<void> _check() async {
    if (offline) throw TimeoutException('sin internet');
  }

  @override
  Future<void> addItems(String listId, List<SharedListItem> newItems) async {
    await _check();
    await super.addItems(listId, newItems);
  }

  @override
  Future<void> setItemDone(
    String listId,
    String itemId, {
    required bool done,
  }) async {
    await _check();
    await super.setItemDone(listId, itemId, done: done);
  }

  @override
  Future<void> createList(SharedList list) async {
    await _check();
    await super.createList(list);
  }
}

void main() {
  final now = DateTime(2026, 10, 3, 10);
  late FlakySharing remote;
  late OfflineSharingRepository offline;
  late SharedPreferences prefs;

  SharedListItem item(String id, String text) =>
      SharedListItem(id: id, text: text, addedBy: 'Ana', addedAt: now);

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    remote = FlakySharing();
    offline = OfflineSharingRepository(
      remote,
      prefs,
      writeTimeout: const Duration(milliseconds: 300),
    );
    await remote.createList(
      SharedList(
        id: 'm',
        name: 'Mercado',
        ownerUid: 'ana',
        memberEmails: const ['ana@gmail.com'],
        createdAt: now,
      ),
    );
  });

  test('sin internet guarda en cola y se ve al instante', () async {
    remote.offline = true;
    final seen = <List<String>>[];
    final sub = offline
        .watchItems('m')
        .listen((items) => seen.add([for (final i in items) i.text]));
    await Future<void>.delayed(Duration.zero);

    await offline.addItems('m', [item('1', 'Leche')]);
    await Future<void>.delayed(const Duration(milliseconds: 50));

    expect(seen.last, ['Leche']);
    expect(offline.pendingCount, 1);
    expect(remote.items['m'], isNull);

    // Vuelve la conexión: se sube lo pendiente.
    remote.offline = false;
    await offline.flush();
    expect(remote.items['m']!.values.single.text, 'Leche');
    expect(offline.pendingCount, 0);
    await sub.cancel();
  });

  test('marcar y asignar sin internet se aplican sobre la copia', () async {
    await remote.addItems('m', [item('1', 'Pan'), item('2', 'Huevos')]);
    final first = await offline.watchItems('m').first;
    expect(first.map((i) => i.text), ['Pan', 'Huevos']);

    remote.offline = true;
    await offline.setItemDone('m', '1', done: true);
    await offline.assignItem('m', '2', email: 'SOFI@gmail.com', name: 'Sofi');
    final items = await offline.watchItems('m').first;

    // Lo marcado va al final; la asignación se ve con el correo en
    // minúsculas.
    expect(items.map((i) => i.text), ['Huevos', 'Pan']);
    expect(items.first.assignedTo, 'sofi@gmail.com');
    expect(items.last.done, isTrue);
  });

  test('la copia queda guardada para abrir la lista sin internet', () async {
    await remote.addItems('m', [item('1', 'Café')]);
    await offline.watchItems('m').first;

    // Otra instancia (la app se reabrió) sin conexión.
    final reopened = OfflineSharingRepository(
      FlakySharing()..offline = true,
      prefs,
      writeTimeout: const Duration(milliseconds: 300),
    );
    final items = await reopened.watchItems('m').first;
    expect(items.single.text, 'Café');
  });

  test('una lista creada sin internet aparece y luego se sube', () async {
    remote.offline = true;
    await offline.createList(
      SharedList(
        id: 'casa',
        name: 'Casa',
        ownerUid: 'ana',
        memberEmails: const ['ana@gmail.com'],
        createdAt: now,
      ),
    );
    final lists = await offline.watchLists('ana@gmail.com').first;
    expect(lists.map((l) => l.name), contains('Casa'));

    remote.offline = false;
    await offline.flush();
    expect(remote.lists.containsKey('casa'), isTrue);
  });

  test('cerrar sesión borra la copia y la cola', () async {
    remote.offline = true;
    await offline.addItems('m', [item('1', 'Leche')]);
    await offline.clear();
    expect(offline.pendingCount, 0);
    expect(prefs.getKeys().where((k) => k.startsWith('sharing.')), isEmpty);
  });

  group('responsables por voz', () {
    test('«… a la lista de la casa para Sofi»', () {
      final r = SpanishShareParser.parseListAdd(
        'Agrega pagar el internet a la lista de la casa para Sofía',
      )!;
      expect(r.items, ['Pagar el internet']);
      expect(r.listName, 'casa');
      expect(r.assignee, 'Sofía');

      final none = SpanishShareParser.parseListAdd(
        'agrega leche a la lista del mercado',
      )!;
      expect(none.assignee, isNull);
    });

    test('«¿qué me toca en la lista de la casa?»', () {
      expect(
        SpanishShareParser.parseListMine(
          '¿Qué me toca en la lista de la casa?',
        ),
        'casa',
      );
      expect(
        SpanishShareParser.parseListMine(
          'qué tengo asignado en la lista del mercado',
        ),
        'mercado',
      );
      expect(SpanishShareParser.parseListMine('qué hay en la lista'), isNull);
    });
  });
}
