import 'package:flutter/foundation.dart';
import 'package:viernes/ai/nlu/es/spanish_text.dart';

/// Persona con la que se comparte («Sofi» → sofi@gmail.com).
@immutable
class Contact {
  const Contact({required this.name, required this.email});

  factory Contact.fromJson(Map<String, Object?> json) => Contact(
    name: json['name']! as String,
    email: json['email']! as String,
  );

  final String name;

  /// Correo de su cuenta de Google en Viernes (en minúsculas).
  final String email;

  String get key => SpanishText.fold(name).trim();

  Map<String, Object?> toJson() => {'name': name, 'email': email};

  @override
  bool operator ==(Object other) =>
      other is Contact && other.name == name && other.email == email;

  @override
  int get hashCode => Object.hash(name, email);
}

/// En qué va un recordatorio enviado a otra persona.
enum SharedStatus {
  /// Enviado; aún no llega a su teléfono.
  sent,

  /// Ya está en su agenda.
  accepted,

  /// Lo hizo.
  done,

  /// El que lo envió lo canceló.
  cancelled,
}

/// Recordatorio que una persona le envía a otra.
@immutable
class SharedReminder {
  const SharedReminder({
    required this.id,
    required this.fromUid,
    required this.fromName,
    required this.fromEmail,
    required this.toEmail,
    required this.title,
    required this.dueAt,
    required this.createdAt,
    this.leadTime = Duration.zero,
    this.status = SharedStatus.sent,
    this.doneAt,
  });

  final String id;
  final String fromUid;
  final String fromName;
  final String fromEmail;
  final String toEmail;
  final String title;
  final DateTime dueAt;
  final Duration leadTime;
  final DateTime createdAt;
  final SharedStatus status;
  final DateTime? doneAt;

  SharedReminder copyWith({SharedStatus? status, DateTime? doneAt}) =>
      SharedReminder(
        id: id,
        fromUid: fromUid,
        fromName: fromName,
        fromEmail: fromEmail,
        toEmail: toEmail,
        title: title,
        dueAt: dueAt,
        leadTime: leadTime,
        createdAt: createdAt,
        status: status ?? this.status,
        doneAt: doneAt ?? this.doneAt,
      );
}

/// Lista compartida (mercado, pendientes de la casa…).
@immutable
class SharedList {
  const SharedList({
    required this.id,
    required this.name,
    required this.ownerUid,
    required this.memberEmails,
    required this.createdAt,
  });

  final String id;
  final String name;
  final String ownerUid;

  /// Quiénes la ven y la editan (en minúsculas).
  final List<String> memberEmails;
  final DateTime createdAt;

  String get key => SpanishText.fold(name).trim();
}

@immutable
class SharedListItem {
  const SharedListItem({
    required this.id,
    required this.text,
    required this.addedBy,
    required this.addedAt,
    this.done = false,
  });

  final String id;
  final String text;

  /// Nombre de quien lo agregó.
  final String addedBy;
  final DateTime addedAt;
  final bool done;
}
