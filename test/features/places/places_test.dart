import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:viernes/ai/nlu/es/spanish_place_trigger.dart';
import 'package:viernes/core/database/app_database.dart';
import 'package:viernes/features/places/application/geofence_sync.dart';
import 'package:viernes/features/places/data/places_repository.dart';
import 'package:viernes/features/places/domain/place.dart';

import '../../helpers/fake_location.dart';

void main() {
  final home = Place(
    id: 'casa',
    name: 'Casa',
    latitude: 1.2,
    longitude: -77.3,
    createdAt: DateTime(2026, 10),
  );
  final market = Place(
    id: 'super',
    name: 'Supermercado',
    latitude: 1.3,
    longitude: -77.2,
    radiusMeters: 250,
    createdAt: DateTime(2026, 10),
  );

  group('SpanishPlaceTrigger', () {
    test('entiende al llegar y al salir', () {
      final a = SpanishPlaceTrigger.parse(
        'Recuérdame comprar leche cuando llegue a casa',
      )!;
      expect(a.onArrive, isTrue);
      expect(a.placeText, 'casa');
      expect(a.task, 'Comprar leche');

      final b = SpanishPlaceTrigger.parse(
        'avísame llamar a Juan al salir del trabajo',
      )!;
      expect(b.onArrive, isFalse);
      expect(b.placeText, 'trabajo');
      expect(b.task, 'Llamar a Juan');

      final c = SpanishPlaceTrigger.parse(
        'comprar pilas cuando pase por el súper',
      )!;
      expect(c.placeText, 'super');

      expect(SpanishPlaceTrigger.parse('mañana a las 8 correr'), isNull);
    });

    test('encuentra el lugar guardado', () {
      expect(SpanishPlaceTrigger.findPlace('casa', [home, market]), home);
      expect(SpanishPlaceTrigger.findPlace('super', [home, market]), market);
      expect(SpanishPlaceTrigger.findPlace('banco', [home, market]), isNull);
    });
  });

  test('registra geocercas solo de los pendientes', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final repository = PlacesRepository(db);
    final bridge = FakeLocationBridge();
    await repository.savePlace(home);
    await repository.savePlace(market);
    await repository.saveReminder(
      LocationReminder(
        id: 'r1',
        title: 'Comprar leche',
        placeId: 'super',
        createdAt: DateTime(2026, 10),
      ),
    );
    await repository.saveReminder(
      LocationReminder(
        id: 'r2',
        title: 'Sacar la basura',
        placeId: 'casa',
        onArrive: false,
        createdAt: DateTime(2026, 10),
      ),
    );
    await repository.setDone('r2', done: true, at: DateTime(2026, 10, 2));

    await GeofenceSync(repository, bridge).sync();

    expect(bridge.geofences.single.id, 'r1');
    expect(bridge.geofences.single.radius, 250);
    expect(bridge.geofences.single.placeName, 'Supermercado');

    await repository.deletePlace('super');
    await GeofenceSync(repository, bridge).sync();
    expect(bridge.geofences, isEmpty);
  });
}
