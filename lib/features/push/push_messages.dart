import 'package:flutter/foundation.dart';

/// Tipos de mensajes push que envían las funciones de la nube
/// (`functions/index.js`). Son mensajes de datos: la app decide qué mostrar.
abstract final class PushTypes {
  /// Alguien te envió un recordatorio (`id`, `title`, `fromName`).
  static const sharedReminder = 'shared_reminder';

  /// Completaron lo que enviaste (`id`, `title`, `toEmail`).
  static const sharedDone = 'shared_done';

  /// Te asignaron algo en una lista (`listId`, `listName`, `itemId`, `text`,
  /// `by`).
  static const listAssigned = 'list_assigned';

  /// Te agregaron a una lista (`listId`, `listName`, `by`).
  static const listInvite = 'list_invite';
}

/// Texto del aviso que corresponde a un mensaje push.
@immutable
class PushNotice {
  const PushNotice({
    required this.id,
    required this.title,
    required this.body,
  });

  final int id;
  final String title;
  final String body;

  /// Nulo si el mensaje no se muestra (tipo desconocido o datos
  /// incompletos).
  static PushNotice? from(
    Map<String, Object?> data, {
    String Function(String email)? nameOf,
  }) {
    String text(String key) => (data[key] as String?)?.trim() ?? '';
    final type = text('type');
    int idFor(String key) => 0x7C000000 + (key.hashCode & 0xFFFF);
    switch (type) {
      case PushTypes.sharedReminder:
        final from = text('fromName');
        final title = text('title');
        if (title.isEmpty) return null;
        return PushNotice(
          id: idFor(text('id')),
          title: from.isEmpty
              ? 'Te enviaron un recordatorio'
              : '$from te envió un recordatorio',
          body: title,
        );
      case PushTypes.sharedDone:
        final to = text('toEmail');
        final who = to.isEmpty ? 'Lo hicieron' : (nameOf?.call(to) ?? to);
        return PushNotice(
          id: idFor(text('id')),
          title: '$who lo hizo ✓',
          body: text('title'),
        );
      case PushTypes.listAssigned:
        final list = text('listName');
        final by = text('by');
        return PushNotice(
          id: idFor(text('itemId')),
          title: 'En la lista $list te toca',
          body: by.isEmpty ? text('text') : '${text('text')} (de $by)',
        );
      case PushTypes.listInvite:
        final by = text('by');
        return PushNotice(
          id: idFor('invite-${text('listId')}'),
          title: 'Te agregaron a una lista',
          body: by.isEmpty
              ? 'Lista «${text('listName')}»'
              : '$by te agregó a «${text('listName')}»',
        );
    }
    return null;
  }
}
