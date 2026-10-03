import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:viernes/features/settings/data/settings_repository.dart';
import 'package:viernes/features/settings/domain/app_settings.dart';

void main() {
  group('horario de silencio', () {
    test('desactivado nunca silencia', () {
      expect(const AppSettings().isQuietAt(DateTime(2026, 1, 1, 23)), isFalse);
    });

    test('cruza la medianoche (22:00 → 7:00)', () {
      const settings = AppSettings(quietHoursEnabled: true);
      expect(settings.isQuietAt(DateTime(2026, 1, 1, 23)), isTrue);
      expect(settings.isQuietAt(DateTime(2026, 1, 1, 6, 59)), isTrue);
      expect(settings.isQuietAt(DateTime(2026, 1, 1, 7)), isFalse);
      expect(settings.isQuietAt(DateTime(2026, 1, 1, 21, 59)), isFalse);
    });

    test('dentro del mismo día (13:00 → 15:00)', () {
      const settings = AppSettings(
        quietHoursEnabled: true,
        quietHoursStart: DayTime(13, 0),
        quietHoursEnd: DayTime(15, 0),
      );
      expect(settings.isQuietAt(DateTime(2026, 1, 1, 14)), isTrue);
      expect(settings.isQuietAt(DateTime(2026, 1, 1, 15)), isFalse);
    });
  });

  test('SettingsRepository guarda y recupera las preferencias', () async {
    SharedPreferences.setMockInitialValues({});
    final repository = SettingsRepository(
      await SharedPreferences.getInstance(),
    );
    expect(repository.load().snoozeDuration, const Duration(minutes: 10));

    const custom = AppSettings(
      defaultLeadTime: Duration(hours: 1),
      snoozeDuration: Duration(minutes: 30),
      quietHoursEnabled: true,
      quietHoursStart: DayTime(23, 30),
      dataCollectionConsent: true,
      themeMode: AppThemeMode.dark,
    );
    await repository.save(custom);
    final loaded = repository.load();

    expect(loaded.defaultLeadTime, custom.defaultLeadTime);
    expect(loaded.snoozeDuration, custom.snoozeDuration);
    expect(loaded.quietHoursEnabled, isTrue);
    expect(loaded.quietHoursStart, const DayTime(23, 30));
    expect(loaded.dataCollectionConsent, isTrue);
    expect(loaded.themeMode, AppThemeMode.dark);
  });
}
