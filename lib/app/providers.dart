import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:viernes/app/flavor.dart';
import 'package:viernes/core/database/app_database.dart';
import 'package:viernes/core/utils/clock.dart';
import 'package:viernes/core/utils/id_generator.dart';

// Dependencias transversales. Las que dependen del arranque se sobrescriben
// en `bootstrap`.

final flavorProvider = Provider<AppFlavor>((ref) => AppFlavor.dev);

final sharedPreferencesProvider = Provider<SharedPreferences>(
  (ref) => throw UnimplementedError('Se inicializa en bootstrap()'),
);

final clockProvider = Provider<Clock>((ref) => const SystemClock());

final idGeneratorProvider = Provider<IdGenerator>(
  (ref) => const UuidIdGenerator(),
);

final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase.open();
  ref.onDispose(db.close);
  return db;
});

/// Hora actual que se actualiza cada minuto, para que los estados "vencido"
/// u "hoy" se refresquen solos en pantalla.
final nowProvider = StreamProvider<DateTime>((ref) {
  final clock = ref.watch(clockProvider);
  final now = clock.now();
  final controller = StreamController<DateTime>()..add(now);
  Timer? periodic;
  final firstTick = Timer(
    Duration(seconds: 60 - now.second),
    () {
      controller.add(clock.now());
      periodic = Timer.periodic(
        const Duration(minutes: 1),
        (_) => controller.add(clock.now()),
      );
    },
  );
  ref.onDispose(() {
    firstTick.cancel();
    periodic?.cancel();
    unawaited(controller.close());
  });
  return controller.stream;
});
