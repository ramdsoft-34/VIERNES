import 'package:flutter/foundation.dart';
import 'package:viernes/core/utils/day_time.dart';

export 'package:viernes/core/utils/day_time.dart';

enum AppThemeMode { system, light, dark }

/// Detector de la palabra «Viernes».
enum WakeEngine {
  /// Modelo propio incluido en la app (ligero, sin descarga).
  own,

  /// Vosk: modelo de voz general de ~38 MB (respaldo).
  vosk,
}

/// Modo conducción: respuestas cortas y botones grandes.
enum DrivingMode {
  off,

  /// Se activa solo con el modo carro de Android o el Bluetooth del carro.
  auto,
  on,
}

/// Preferencias del usuario.
@immutable
class AppSettings {
  const AppSettings({
    this.defaultLeadTime = const Duration(minutes: 15),
    this.snoozeDuration = const Duration(minutes: 10),
    this.fullScreenAlerts = true,
    this.soundEnabled = true,
    this.vibrationEnabled = true,
    this.escalationEnabled = true,
    this.quietHoursEnabled = false,
    this.quietHoursStart = const DayTime(22, 0),
    this.quietHoursEnd = const DayTime(7, 0),
    this.morningSummaryEnabled = true,
    this.morningSummaryTime = const DayTime(7, 0),
    this.nightSummaryEnabled = true,
    this.nightSummaryTime = const DayTime(21, 0),
    this.voiceConfirmation = true,
    this.dataCollectionConsent = false,
    this.themeMode = AppThemeMode.dark,
    this.wakeWordEnabled = false,
    this.wakeSensitivity = 0.5,
    this.wakeEngine = WakeEngine.own,
    this.neuralTitles = false,
    this.wakeChime = true,
    this.personalLearning = true,
    this.includeCalendar = false,
    this.speakBriefing = true,
    this.drivingMode = DrivingMode.auto,
    this.lowBatteryPause = true,
    this.autoBirthdays = false,
    this.birthdayTime = const DayTime(8, 0),
    this.birthdayDaysBefore = 1,
  });

  static const leadTimeOptions = <Duration>[
    Duration.zero,
    Duration(minutes: 5),
    Duration(minutes: 10),
    Duration(minutes: 15),
    Duration(minutes: 30),
    Duration(hours: 1),
    Duration(hours: 2),
    Duration(days: 1),
  ];

  /// Días de anticipación para el aviso previo de un cumpleaños.
  static const birthdayDaysOptions = <int>[0, 1, 2, 3, 7];

  static const snoozeOptions = <Duration>[
    Duration(minutes: 5),
    Duration(minutes: 10),
    Duration(minutes: 15),
    Duration(minutes: 30),
    Duration(hours: 1),
  ];

  /// Intervalos de insistencia cuando el usuario no responde una alerta.
  static const escalationSteps = <Duration>[
    Duration(minutes: 10),
    Duration(minutes: 30),
    Duration(minutes: 60),
  ];

  final Duration defaultLeadTime;
  final Duration snoozeDuration;
  final bool fullScreenAlerts;
  final bool soundEnabled;
  final bool vibrationEnabled;
  final bool escalationEnabled;
  final bool quietHoursEnabled;
  final DayTime quietHoursStart;
  final DayTime quietHoursEnd;
  final bool morningSummaryEnabled;
  final DayTime morningSummaryTime;
  final bool nightSummaryEnabled;
  final DayTime nightSummaryTime;
  final bool voiceConfirmation;

  /// Consentimiento explícito (opt-in) para guardar frases y correcciones con
  /// las que se entrena el intérprete propio.
  final bool dataCollectionConsent;
  final AppThemeMode themeMode;

  /// Escuchar la palabra "Viernes" en segundo plano.
  final bool wakeWordEnabled;

  /// 0 = menos falsas activaciones; 1 = responde más fácil.
  final double wakeSensitivity;

  final WakeEngine wakeEngine;

  /// Experimental: la red neuronal propia decide el título de los
  /// recordatorios cuando está muy segura (si no, solo llena huecos).
  final bool neuralTitles;

  /// Sonido corto al oír «Viernes», antes de «Te escucho».
  final bool wakeChime;

  /// Que Viernes aprenda de los recordatorios del usuario (categorías,
  /// horarios, anticipación). Todo ocurre en el teléfono.
  final bool personalLearning;

  /// Leer el calendario del teléfono (Google Calendar) para responder
  /// «¿tengo algo el viernes?» y para los resúmenes.
  final bool includeCalendar;

  /// Al tocar el resumen de la mañana, Viernes lo lee en voz alta.
  final bool speakBriefing;

  final DrivingMode drivingMode;

  /// Pausar la escucha de «Viernes» con poca batería (15 % o menos, sin
  /// cargar).
  final bool lowBatteryPause;

  /// Agregar solos los cumpleaños nuevos de los contactos.
  final bool autoBirthdays;

  /// Hora del aviso de cada cumpleaños.
  final DayTime birthdayTime;

  /// Días antes para el aviso previo (0 = sin aviso previo).
  final int birthdayDaysBefore;

  /// Confianza mínima que exige el detector según la sensibilidad
  /// (entre 0,95 y 0,65).
  double get wakeThreshold => 0.95 - 0.3 * wakeSensitivity.clamp(0, 1);

  /// Umbral del detector propio: su salida es una probabilidad calibrada en
  /// el entrenamiento: 0,6 en sensibilidad media (~65 % de detección y menos
  /// de una activación falsa por hora, ver training/results).
  double get ownWakeThreshold => 0.85 - 0.5 * wakeSensitivity.clamp(0, 1);

  /// Si [moment] cae dentro del horario de silencio (admite cruzar medianoche).
  bool isQuietAt(DateTime moment) {
    if (!quietHoursEnabled) return false;
    final minutes = moment.hour * 60 + moment.minute;
    final start = quietHoursStart.inMinutes;
    final end = quietHoursEnd.inMinutes;
    if (start == end) return false;
    return start < end
        ? minutes >= start && minutes < end
        : minutes >= start || minutes < end;
  }

  AppSettings copyWith({
    Duration? defaultLeadTime,
    Duration? snoozeDuration,
    bool? fullScreenAlerts,
    bool? soundEnabled,
    bool? vibrationEnabled,
    bool? escalationEnabled,
    bool? quietHoursEnabled,
    DayTime? quietHoursStart,
    DayTime? quietHoursEnd,
    bool? morningSummaryEnabled,
    DayTime? morningSummaryTime,
    bool? nightSummaryEnabled,
    DayTime? nightSummaryTime,
    bool? voiceConfirmation,
    bool? dataCollectionConsent,
    AppThemeMode? themeMode,
    bool? wakeWordEnabled,
    double? wakeSensitivity,
    WakeEngine? wakeEngine,
    bool? neuralTitles,
    bool? wakeChime,
    bool? personalLearning,
    bool? includeCalendar,
    bool? speakBriefing,
    DrivingMode? drivingMode,
    bool? lowBatteryPause,
    bool? autoBirthdays,
    DayTime? birthdayTime,
    int? birthdayDaysBefore,
  }) => AppSettings(
    defaultLeadTime: defaultLeadTime ?? this.defaultLeadTime,
    snoozeDuration: snoozeDuration ?? this.snoozeDuration,
    fullScreenAlerts: fullScreenAlerts ?? this.fullScreenAlerts,
    soundEnabled: soundEnabled ?? this.soundEnabled,
    vibrationEnabled: vibrationEnabled ?? this.vibrationEnabled,
    escalationEnabled: escalationEnabled ?? this.escalationEnabled,
    quietHoursEnabled: quietHoursEnabled ?? this.quietHoursEnabled,
    quietHoursStart: quietHoursStart ?? this.quietHoursStart,
    quietHoursEnd: quietHoursEnd ?? this.quietHoursEnd,
    morningSummaryEnabled: morningSummaryEnabled ?? this.morningSummaryEnabled,
    morningSummaryTime: morningSummaryTime ?? this.morningSummaryTime,
    nightSummaryEnabled: nightSummaryEnabled ?? this.nightSummaryEnabled,
    nightSummaryTime: nightSummaryTime ?? this.nightSummaryTime,
    voiceConfirmation: voiceConfirmation ?? this.voiceConfirmation,
    dataCollectionConsent: dataCollectionConsent ?? this.dataCollectionConsent,
    themeMode: themeMode ?? this.themeMode,
    wakeWordEnabled: wakeWordEnabled ?? this.wakeWordEnabled,
    wakeSensitivity: wakeSensitivity ?? this.wakeSensitivity,
    wakeEngine: wakeEngine ?? this.wakeEngine,
    neuralTitles: neuralTitles ?? this.neuralTitles,
    wakeChime: wakeChime ?? this.wakeChime,
    personalLearning: personalLearning ?? this.personalLearning,
    includeCalendar: includeCalendar ?? this.includeCalendar,
    speakBriefing: speakBriefing ?? this.speakBriefing,
    drivingMode: drivingMode ?? this.drivingMode,
    lowBatteryPause: lowBatteryPause ?? this.lowBatteryPause,
    autoBirthdays: autoBirthdays ?? this.autoBirthdays,
    birthdayTime: birthdayTime ?? this.birthdayTime,
    birthdayDaysBefore: birthdayDaysBefore ?? this.birthdayDaysBefore,
  );
}
