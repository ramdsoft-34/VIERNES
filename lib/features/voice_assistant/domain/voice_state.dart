import 'package:flutter/foundation.dart';
import 'package:viernes/core/platform/device_data.dart';
import 'package:viernes/features/reminders/domain/entities/recurrence.dart';
import 'package:viernes/features/reminders/domain/entities/reminder.dart';
import 'package:viernes/features/reminders/domain/entities/reminder_enums.dart';

enum VoiceStage {
  idle,

  /// Viernes habla o escucha una frase.
  listening,

  /// Interpretando lo que se dijo.
  thinking,

  /// Mostrando lo entendido y esperando "sí", una corrección o un botón.
  confirming,

  /// Terminó bien: guardó o respondió.
  done,

  /// Terminó sin resultado (no entendió, sin permiso, sin voz…).
  failed,
}

/// Vista previa de lo que Viernes entendió.
@immutable
class VoicePreview {
  const VoicePreview({
    required this.title,
    required this.leadTime,
    required this.recurrence,
    required this.priority,
    required this.category,
    this.due,
  });

  final String title;
  final DateTime? due;
  final Duration leadTime;
  final Recurrence recurrence;
  final ReminderPriority priority;
  final ReminderCategory category;
}

@immutable
class VoiceState {
  const VoiceState({
    this.stage = VoiceStage.idle,
    this.message = '',
    this.transcript = '',
    this.isListening = false,
    this.preview,
    this.saved,
    this.agenda,
    this.events,
    this.driving = false,
  });

  final VoiceStage stage;

  /// Lo que Viernes dice y muestra.
  final String message;

  /// Lo que el usuario está diciendo o acaba de decir.
  final String transcript;
  final bool isListening;
  final VoicePreview? preview;
  final Reminder? saved;

  /// Recordatorios de la respuesta a "¿qué tengo hoy?".
  final List<Reminder>? agenda;

  /// Eventos del calendario del teléfono que acompañan la respuesta.
  final List<CalendarEvent>? events;

  /// Modo conducción: textos y botones grandes, respuestas cortas.
  final bool driving;

  bool get isBusy =>
      stage == VoiceStage.listening ||
      stage == VoiceStage.thinking ||
      stage == VoiceStage.confirming;

  VoiceState copyWith({
    VoiceStage? stage,
    String? message,
    String? transcript,
    bool? isListening,
    VoicePreview? preview,
    bool clearPreview = false,
    Reminder? saved,
    List<Reminder>? agenda,
    List<CalendarEvent>? events,
    bool? driving,
  }) => VoiceState(
    stage: stage ?? this.stage,
    message: message ?? this.message,
    transcript: transcript ?? this.transcript,
    isListening: isListening ?? this.isListening,
    preview: clearPreview ? null : preview ?? this.preview,
    saved: saved ?? this.saved,
    agenda: agenda ?? this.agenda,
    events: events ?? this.events,
    driving: driving ?? this.driving,
  );
}
