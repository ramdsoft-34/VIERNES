import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:viernes/app/providers.dart';
import 'package:viernes/features/settings/data/settings_repository.dart';
import 'package:viernes/features/settings/domain/app_settings.dart';

final settingsRepositoryProvider = Provider<SettingsRepository>(
  (ref) => SettingsRepository(ref.watch(sharedPreferencesProvider)),
);

final settingsControllerProvider =
    NotifierProvider<SettingsController, AppSettings>(SettingsController.new);

class SettingsController extends Notifier<AppSettings> {
  @override
  AppSettings build() => ref.watch(settingsRepositoryProvider).load();

  /// Aplica el cambio de inmediato en la UI y lo persiste en segundo plano.
  void update(AppSettings Function(AppSettings current) change) {
    state = change(state);
    unawaited(ref.read(settingsRepositoryProvider).save(state));
  }

  /// Vuelve a leer lo guardado (p. ej. tras restaurar desde la cuenta).
  void reload() => state = ref.read(settingsRepositoryProvider).load();
}
