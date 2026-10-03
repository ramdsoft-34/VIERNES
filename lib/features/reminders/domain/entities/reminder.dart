import 'package:flutter/foundation.dart';
import 'package:viernes/features/reminders/domain/entities/recurrence.dart';
import 'package:viernes/features/reminders/domain/entities/reminder_enums.dart';

const Object _unset = Object();

/// Un recordatorio. Entidad inmutable del dominio.
@immutable
class Reminder {
  const Reminder({
    required this.id,
    required this.title,
    required this.dueAt,
    required this.createdAt,
    required this.updatedAt,
    this.notes,
    this.leadTime = Duration.zero,
    this.recurrence = Recurrence.none,
    this.priority = ReminderPriority.normal,
    this.category = ReminderCategory.other,
    this.status = ReminderStatus.pending,
    this.snoozedUntil,
    this.snoozeCount = 0,
    this.source = ReminderSource.manual,
    this.rawUtterance,
    this.nluConfidence,
    this.completedAt,
  });

  final String id;

  /// Qué hay que hacer: "Entregar el informe".
  final String title;
  final String? notes;

  /// Momento del evento o fecha límite ("antes de las 8" → 8:00).
  final DateTime dueAt;

  /// Cuánto antes de [dueAt] se avisa.
  final Duration leadTime;

  final Recurrence recurrence;
  final ReminderPriority priority;
  final ReminderCategory category;
  final ReminderStatus status;

  /// Si está pospuesto, cuándo se vuelve a avisar.
  final DateTime? snoozedUntil;

  /// Veces que se pospuso la ocurrencia actual.
  final int snoozeCount;

  final ReminderSource source;

  /// Frase original dictada, para auditar y entrenar el intérprete.
  final String? rawUtterance;

  /// Confianza (0–1) del intérprete al crear el recordatorio por voz.
  final double? nluConfidence;

  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? completedAt;

  /// Momento programado del aviso.
  DateTime get remindAt => dueAt.subtract(leadTime);

  /// Próximo momento en el que Viernes debe avisar.
  DateTime get nextTriggerAt =>
      status == ReminderStatus.snoozed && snoozedUntil != null
      ? snoozedUntil!
      : remindAt;

  bool get isActive => status != ReminderStatus.completed;

  bool isOverdue(DateTime now) => isActive && dueAt.isBefore(now);

  Reminder copyWith({
    String? title,
    Object? notes = _unset,
    DateTime? dueAt,
    Duration? leadTime,
    Recurrence? recurrence,
    ReminderPriority? priority,
    ReminderCategory? category,
    ReminderStatus? status,
    Object? snoozedUntil = _unset,
    int? snoozeCount,
    ReminderSource? source,
    Object? rawUtterance = _unset,
    Object? nluConfidence = _unset,
    DateTime? updatedAt,
    Object? completedAt = _unset,
  }) {
    return Reminder(
      id: id,
      title: title ?? this.title,
      notes: identical(notes, _unset) ? this.notes : notes as String?,
      dueAt: dueAt ?? this.dueAt,
      leadTime: leadTime ?? this.leadTime,
      recurrence: recurrence ?? this.recurrence,
      priority: priority ?? this.priority,
      category: category ?? this.category,
      status: status ?? this.status,
      snoozedUntil: identical(snoozedUntil, _unset)
          ? this.snoozedUntil
          : snoozedUntil as DateTime?,
      snoozeCount: snoozeCount ?? this.snoozeCount,
      source: source ?? this.source,
      rawUtterance: identical(rawUtterance, _unset)
          ? this.rawUtterance
          : rawUtterance as String?,
      nluConfidence: identical(nluConfidence, _unset)
          ? this.nluConfidence
          : nluConfidence as double?,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      completedAt: identical(completedAt, _unset)
          ? this.completedAt
          : completedAt as DateTime?,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is Reminder &&
      other.id == id &&
      other.title == title &&
      other.notes == notes &&
      other.dueAt == dueAt &&
      other.leadTime == leadTime &&
      other.recurrence == recurrence &&
      other.priority == priority &&
      other.category == category &&
      other.status == status &&
      other.snoozedUntil == snoozedUntil &&
      other.snoozeCount == snoozeCount &&
      other.source == source &&
      other.rawUtterance == rawUtterance &&
      other.nluConfidence == nluConfidence &&
      other.createdAt == createdAt &&
      other.updatedAt == updatedAt &&
      other.completedAt == completedAt;

  @override
  int get hashCode => Object.hash(
    id,
    title,
    notes,
    dueAt,
    leadTime,
    recurrence,
    priority,
    category,
    status,
    snoozedUntil,
    snoozeCount,
    source,
    rawUtterance,
    nluConfidence,
    createdAt,
    updatedAt,
    completedAt,
  );

  @override
  String toString() => 'Reminder($id, "$title", $dueAt, ${status.name})';
}
