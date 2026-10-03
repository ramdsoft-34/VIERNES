import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:viernes/core/error/result.dart';
import 'package:viernes/core/logging/app_logger.dart';
import 'package:viernes/features/reminders/domain/entities/reminder.dart';
import 'package:viernes/features/reminders/domain/entities/reminder_draft.dart';
import 'package:viernes/features/reminders/domain/entities/reminder_enums.dart';
import 'package:viernes/features/sharing/domain/sharing_models.dart';
import 'package:viernes/features/sharing/domain/sharing_repository.dart';

/// Muestra un aviso inmediato (no programado).
abstract interface class InfoNotifier {
  Future<void> showInfo({
    required int id,
    required String title,
    required String body,
  });
}

/// Qué recordatorio local corresponde a cada recordatorio compartido.
class SharedLinks {
  SharedLinks(this._prefs);

  final SharedPreferences _prefs;

  static const _linksKey = 'sharing.links';
  static const _reportedKey = 'sharing.reported';
  static const _notifiedKey = 'sharing.notifiedDone';

  /// id local → id compartido.
  Map<String, String> links() {
    final raw = _prefs.getString(_linksKey);
    if (raw == null) return {};
    return Map<String, String>.from(jsonDecode(raw) as Map);
  }

  Future<void> link(String localId, String sharedId) =>
      _prefs.setString(_linksKey, jsonEncode({...links(), localId: sharedId}));

  Set<String> _set(String key) => (_prefs.getStringList(key) ?? []).toSet();

  Future<void> _add(String key, String value) =>
      _prefs.setStringList(key, [..._set(key), value]);

  bool reported(String sharedId) => _set(_reportedKey).contains(sharedId);

  Future<void> markReported(String sharedId) => _add(_reportedKey, sharedId);

  bool notified(String sharedId) => _set(_notifiedKey).contains(sharedId);

  Future<void> markNotified(String sharedId) => _add(_notifiedKey, sharedId);
}

/// Recibe lo que otras personas envían y avisa cuando se completa.
class SharedInbox {
  SharedInbox({
    required this._remote,
    required this._create,
    required this._links,
    required this._notifier,
    required this._now,
  });

  final SharingRepository _remote;
  final Future<Result<Reminder>> Function(ReminderDraft draft) _create;
  final SharedLinks _links;
  final InfoNotifier _notifier;
  final DateTime Function() _now;

  /// Agrega a la agenda lo recibido y lo marca como aceptado.
  Future<void> accept(List<SharedReminder> incoming) async {
    for (final shared in incoming) {
      if (_links.links().containsValue(shared.id)) {
        await _remote.setStatus(shared.id, SharedStatus.accepted);
        continue;
      }
      final result = await _create(
        ReminderDraft(
          title: shared.title,
          dueAt: shared.dueAt,
          leadTime: shared.leadTime,
          notes: 'Te lo envió ${shared.fromName}',
          source: ReminderSource.shared,
        ),
      );
      switch (result) {
        case Ok(:final value):
          await _links.link(value.id, shared.id);
          await _remote.setStatus(shared.id, SharedStatus.accepted);
          await _notifier.showInfo(
            id: _notificationId(shared.id),
            title: '${shared.fromName} te envió un recordatorio',
            body: shared.title,
          );
        case Err(:final failure):
          AppLogger.error('No se pudo recibir el recordatorio: $failure');
      }
    }
  }

  /// Avisa a quien lo envió cuando se completa aquí.
  Future<void> reportCompleted(List<Reminder> completed) async {
    final links = _links.links();
    for (final reminder in completed) {
      final sharedId = links[reminder.id];
      if (sharedId == null || _links.reported(sharedId)) continue;
      await _remote.setStatus(
        sharedId,
        SharedStatus.done,
        at: reminder.completedAt ?? _now(),
      );
      await _links.markReported(sharedId);
    }
  }

  /// Notifica cuando la otra persona completa lo que le envié.
  /// Con [silent] solo los marca (al abrir la app no se repiten avisos viejos).
  Future<void> notifyDone(
    List<SharedReminder> sent,
    List<Contact> contacts, {
    bool silent = false,
  }) async {
    for (final shared in sent) {
      if (shared.status != SharedStatus.done || _links.notified(shared.id)) {
        continue;
      }
      if (silent) {
        await _links.markNotified(shared.id);
        continue;
      }
      final who = contacts
          .where((c) => c.email == shared.toEmail)
          .map((c) => c.name)
          .firstOrNull;
      await _notifier.showInfo(
        id: _notificationId(shared.id),
        title: '${who ?? shared.toEmail} lo hizo ✓',
        body: shared.title,
      );
      await _links.markNotified(shared.id);
    }
  }

  /// Ids fuera del rango de los recordatorios.
  static int _notificationId(String id) => 0x7E000000 + (id.hashCode & 0xFFFF);
}
