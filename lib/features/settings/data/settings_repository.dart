import 'package:shared_preferences/shared_preferences.dart';
import 'package:viernes/core/utils/enum_x.dart';
import 'package:viernes/features/settings/domain/app_settings.dart';

/// Guarda las preferencias en SharedPreferences, una clave por valor para
/// poder agregar opciones nuevas sin migraciones.
class SettingsRepository {
  SettingsRepository(this._prefs);

  final SharedPreferences _prefs;

  static const _prefix = 'settings.';

  AppSettings load() {
    const d = AppSettings();
    return AppSettings(
      defaultLeadTime: _minutes('defaultLeadTime') ?? d.defaultLeadTime,
      snoozeDuration: _minutes('snoozeDuration') ?? d.snoozeDuration,
      fullScreenAlerts: _bool('fullScreenAlerts') ?? d.fullScreenAlerts,
      soundEnabled: _bool('soundEnabled') ?? d.soundEnabled,
      vibrationEnabled: _bool('vibrationEnabled') ?? d.vibrationEnabled,
      escalationEnabled: _bool('escalationEnabled') ?? d.escalationEnabled,
      quietHoursEnabled: _bool('quietHoursEnabled') ?? d.quietHoursEnabled,
      quietHoursStart: _dayTime('quietHoursStart') ?? d.quietHoursStart,
      quietHoursEnd: _dayTime('quietHoursEnd') ?? d.quietHoursEnd,
      morningSummaryEnabled:
          _bool('morningSummaryEnabled') ?? d.morningSummaryEnabled,
      morningSummaryTime:
          _dayTime('morningSummaryTime') ?? d.morningSummaryTime,
      nightSummaryEnabled:
          _bool('nightSummaryEnabled') ?? d.nightSummaryEnabled,
      nightSummaryTime: _dayTime('nightSummaryTime') ?? d.nightSummaryTime,
      voiceConfirmation: _bool('voiceConfirmation') ?? d.voiceConfirmation,
      dataCollectionConsent:
          _bool('dataCollectionConsent') ?? d.dataCollectionConsent,
      themeMode: enumByName(
        AppThemeMode.values,
        _prefs.getString('${_prefix}themeMode') ?? '',
        d.themeMode,
      ),
      wakeWordEnabled: _bool('wakeWordEnabled') ?? d.wakeWordEnabled,
      wakeSensitivity:
          _prefs.getDouble('${_prefix}wakeSensitivity') ?? d.wakeSensitivity,
      personalLearning: _bool('personalLearning') ?? d.personalLearning,
      neuralTitles: _bool('neuralTitles') ?? d.neuralTitles,
      wakeChime: _bool('wakeChime') ?? d.wakeChime,
      wakeEngine: enumByName(
        WakeEngine.values,
        _prefs.getString('${_prefix}wakeEngine') ?? '',
        d.wakeEngine,
      ),
    );
  }

  Future<void> save(AppSettings s) async {
    await Future.wait([
      _setMinutes('defaultLeadTime', s.defaultLeadTime),
      _setMinutes('snoozeDuration', s.snoozeDuration),
      _setBool('fullScreenAlerts', s.fullScreenAlerts),
      _setBool('soundEnabled', s.soundEnabled),
      _setBool('vibrationEnabled', s.vibrationEnabled),
      _setBool('escalationEnabled', s.escalationEnabled),
      _setBool('quietHoursEnabled', s.quietHoursEnabled),
      _setDayTime('quietHoursStart', s.quietHoursStart),
      _setDayTime('quietHoursEnd', s.quietHoursEnd),
      _setBool('morningSummaryEnabled', s.morningSummaryEnabled),
      _setDayTime('morningSummaryTime', s.morningSummaryTime),
      _setBool('nightSummaryEnabled', s.nightSummaryEnabled),
      _setDayTime('nightSummaryTime', s.nightSummaryTime),
      _setBool('voiceConfirmation', s.voiceConfirmation),
      _setBool('dataCollectionConsent', s.dataCollectionConsent),
      _prefs.setString('${_prefix}themeMode', s.themeMode.name),
      _setBool('wakeWordEnabled', s.wakeWordEnabled),
      _prefs.setDouble('${_prefix}wakeSensitivity', s.wakeSensitivity),
      _setBool('personalLearning', s.personalLearning),
      _setBool('neuralTitles', s.neuralTitles),
      _setBool('wakeChime', s.wakeChime),
      _prefs.setString('${_prefix}wakeEngine', s.wakeEngine.name),
    ]);
  }

  /// Ajustes que dependen del teléfono (permisos, modelo descargado) y no
  /// viajan con la cuenta.
  static const _deviceOnly = {'wakeWordEnabled', 'wakeEngine'};

  /// Preferencias para guardar en la cuenta.
  Map<String, Object?> exportForSync() => {
    for (final key in _prefs.getKeys())
      if (key.startsWith(_prefix) &&
          !_deviceOnly.contains(key.substring(_prefix.length)))
        key.substring(_prefix.length): _prefs.get(key),
  };

  /// Restaura las preferencias guardadas en la cuenta. Ignora valores de
  /// tipos desconocidos (p. ej. de una versión más nueva).
  Future<void> importFromSync(Map<String, Object?> values) async {
    for (final MapEntry(:key, :value) in values.entries) {
      if (_deviceOnly.contains(key)) continue;
      final prefKey = '$_prefix$key';
      switch (value) {
        case final bool v:
          await _prefs.setBool(prefKey, v);
        case final int v:
          await _prefs.setInt(prefKey, v);
        case final double v:
          await _prefs.setDouble(prefKey, v);
        case final String v:
          await _prefs.setString(prefKey, v);
      }
    }
  }

  bool? _bool(String key) => _prefs.getBool('$_prefix$key');

  Duration? _minutes(String key) {
    final value = _prefs.getInt('$_prefix$key');
    return value == null ? null : Duration(minutes: value);
  }

  DayTime? _dayTime(String key) {
    final value = _prefs.getInt('$_prefix$key');
    return value == null ? null : DayTime.fromMinutes(value);
  }

  Future<bool> _setBool(String key, bool value) =>
      _prefs.setBool('$_prefix$key', value);

  Future<bool> _setMinutes(String key, Duration value) =>
      _prefs.setInt('$_prefix$key', value.inMinutes);

  Future<bool> _setDayTime(String key, DayTime value) =>
      _prefs.setInt('$_prefix$key', value.inMinutes);
}
