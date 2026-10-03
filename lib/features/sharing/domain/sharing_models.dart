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

  factory SharedList.fromJson(Map<String, Object?> json) => SharedList(
    id: json['id']! as String,
    name: json['name'] as String? ?? '',
    ownerUid: json['ownerUid'] as String? ?? '',
    memberEmails: [
      for (final e in (json['memberEmails'] as List?) ?? const []) '$e',
    ],
    createdAt: DateTime.fromMillisecondsSinceEpoch(
      (json['createdAt'] as num?)?.toInt() ?? 0,
    ),
  );

  final String id;
  final String name;
  final String ownerUid;

  /// Quiénes la ven y la editan (en minúsculas).
  final List<String> memberEmails;
  final DateTime createdAt;

  String get key => SpanishText.fold(name).trim();

  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    'ownerUid': ownerUid,
    'memberEmails': memberEmails,
    'createdAt': createdAt.millisecondsSinceEpoch,
  };
}

@immutable
class SharedListItem {
  const SharedListItem({
    required this.id,
    required this.text,
    required this.addedBy,
    required this.addedAt,
    this.done = false,
    this.assignedTo,
    this.assignedName,
  });

  factory SharedListItem.fromJson(Map<String, Object?> json) => SharedListItem(
    id: json['id']! as String,
    text: json['text'] as String? ?? '',
    addedBy: json['addedBy'] as String? ?? '',
    addedAt: DateTime.fromMillisecondsSinceEpoch(
      (json['addedAt'] as num?)?.toInt() ?? 0,
    ),
    done: json['done'] == true,
    assignedTo: json['assignedTo'] as String?,
    assignedName: json['assignedName'] as String?,
  );

  final String id;
  final String text;

  /// Nombre de quien lo agregó.
  final String addedBy;
  final DateTime addedAt;
  final bool done;

  /// Correo de quien debe hacerlo (en minúsculas), si se asignó.
  final String? assignedTo;

  /// Nombre con el que se muestra a esa persona.
  final String? assignedName;

  SharedListItem copyWith({
    bool? done,
    String? assignedTo,
    String? assignedName,
    bool clearAssignee = false,
  }) => SharedListItem(
    id: id,
    text: text,
    addedBy: addedBy,
    addedAt: addedAt,
    done: done ?? this.done,
    assignedTo: clearAssignee ? null : assignedTo ?? this.assignedTo,
    assignedName: clearAssignee ? null : assignedName ?? this.assignedName,
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'text': text,
    'addedBy': addedBy,
    'addedAt': addedAt.millisecondsSinceEpoch,
    'done': done,
    'assignedTo': assignedTo,
    'assignedName': assignedName,
  };

  @override
  bool operator ==(Object other) =>
      other is SharedListItem &&
      other.id == id &&
      other.text == text &&
      other.addedBy == addedBy &&
      other.addedAt == addedAt &&
      other.done == done &&
      other.assignedTo == assignedTo &&
      other.assignedName == assignedName;

  @override
  int get hashCode =>
      Object.hash(id, text, addedBy, addedAt, done, assignedTo, assignedName);
}
