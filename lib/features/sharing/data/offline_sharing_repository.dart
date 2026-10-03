import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:viernes/core/cloud/cloud.dart';
import 'package:viernes/core/logging/app_logger.dart';
import 'package:viernes/features/sharing/domain/sharing_models.dart';
import 'package:viernes/features/sharing/domain/sharing_repository.dart';

/// Listas compartidas que funcionan sin internet.
///
/// Guarda en el teléfono la última copia de cada lista y una cola de cambios
/// pendientes (agregar, marcar, borrar, asignar, crear). Lo que se ve es la
/// copia de la nube con los cambios pendientes aplicados encima; al volver
/// la conexión, la cola se sube en orden.
///
/// Los recordatorios compartidos y los cambios de miembros siguen
/// necesitando conexión (se envían directo).
class OfflineSharingRepository implements SharingRepository {
  OfflineSharingRepository(
    this._remote,
    this._prefs, {
    this.writeTimeout = const Duration(seconds: 10),
  });

  final SharingRepository _remote;
  final SharedPreferences _prefs;

  /// Tiempo que se espera a la nube antes de dejar el cambio en la cola.
  final Duration writeTimeout;

  static const _outboxKey = 'sharing.outbox';
  static String _listsKey(String email) => 'sharing.cache.lists.$email';
  static String _itemsKey(String listId) => 'sharing.cache.items.$listId';

  final _localChanges = StreamController<void>.broadcast();
  Future<void>? _flushing;

  /// Cambios que aún no llegan a la nube.
  int get pendingCount => _outbox().length;

  // --- Cola ------------------------------------------------------------------

  List<Map<String, Object?>> _outbox() {
    final raw = _prefs.getString(_outboxKey);
    if (raw == null) return [];
    try {
      return [
        for (final op in jsonDecode(raw) as List)
          Map<String, Object?>.from(op as Map),
      ];
    } on Object {
      return [];
    }
  }

  Future<void> _saveOutbox(List<Map<String, Object?>> ops) =>
      _prefs.setString(_outboxKey, jsonEncode(ops));

  Future<void> _enqueue(Map<String, Object?> op) async {
    await _saveOutbox([..._outbox(), op]);
    _localChanges.add(null);
    unawaited(flush());
  }

  /// Sube los cambios pendientes en orden. Se detiene en el primero que no
  /// llega por falta de conexión (se reintenta después).
  Future<void> flush() => _flushing ??= _flush().whenComplete(
    () => _flushing = null,
  );

  Future<void> _flush() async {
    while (true) {
      final ops = _outbox();
      if (ops.isEmpty) return;
      final op = ops.first;
      try {
        await _apply(op).timeout(writeTimeout);
      } on Object catch (error) {
        if (isOfflineError(error)) return;
        // Rechazado por la nube (p. ej. ya no es miembro): se descarta.
        AppLogger.info('Lista compartida: cambio descartado ($error)');
      }
      final rest = _outbox();
      if (rest.isNotEmpty && jsonEncode(rest.first) == jsonEncode(op)) {
        await _saveOutbox(rest.sublist(1));
      }
      _localChanges.add(null);
    }
  }

  Future<void> _apply(Map<String, Object?> op) {
    final listId = op['listId']! as String;
    switch (op['type']) {
      case 'createList':
        return _remote.createList(
          SharedList.fromJson(Map<String, Object?>.from(op['list']! as Map)),
        );
      case 'add':
        return _remote.addItems(listId, [
          SharedListItem.fromJson(
            Map<String, Object?>.from(op['item']! as Map),
          ),
        ]);
      case 'done':
        return _remote.setItemDone(
          listId,
          op['itemId']! as String,
          done: op['done'] == true,
        );
      case 'delete':
        return _remote.deleteItem(listId, op['itemId']! as String);
      case 'assign':
        return _remote.assignItem(
          listId,
          op['itemId']! as String,
          email: op['email'] as String?,
          name: op['name'] as String?,
        );
    }
    return Future.value();
  }

  // --- Copia local -----------------------------------------------------------

  List<SharedListItem>? _cachedItems(String listId) {
    final raw = _prefs.getString(_itemsKey(listId));
    if (raw == null) return null;
    try {
      return [
        for (final item in jsonDecode(raw) as List)
          SharedListItem.fromJson(Map<String, Object?>.from(item as Map)),
      ];
    } on Object {
      return null;
    }
  }

  List<SharedList>? _cachedLists(String email) {
    final raw = _prefs.getString(_listsKey(email));
    if (raw == null) return null;
    try {
      return [
        for (final list in jsonDecode(raw) as List)
          SharedList.fromJson(Map<String, Object?>.from(list as Map)),
      ];
    } on Object {
      return null;
    }
  }

  /// Aplica los cambios pendientes de [listId] sobre [server].
  List<SharedListItem> _overlayItems(
    String listId,
    List<SharedListItem> server,
  ) {
    final byId = {for (final item in server) item.id: item};
    final order = [for (final item in server) item.id];
    for (final op in _outbox()) {
      if (op['listId'] != listId) continue;
      final itemId = op['itemId'] as String?;
      switch (op['type']) {
        case 'add':
          final item = SharedListItem.fromJson(
            Map<String, Object?>.from(op['item']! as Map),
          );
          if (!byId.containsKey(item.id)) order.add(item.id);
          byId[item.id] = item;
        case 'done':
          final item = byId[itemId];
          if (item != null) {
            byId[itemId!] = item.copyWith(done: op['done'] == true);
          }
        case 'delete':
          byId.remove(itemId);
          order.remove(itemId);
        case 'assign':
          final item = byId[itemId];
          if (item == null) break;
          final email = op['email'] as String?;
          byId[itemId!] = email == null
              ? item.copyWith(clearAssignee: true)
              : item.copyWith(
                  assignedTo: email,
                  assignedName: op['name'] as String?,
                );
      }
    }
    return sortItems([for (final id in order) ?byId[id]]);
  }

  List<SharedList> _overlayLists(String email, List<SharedList> server) {
    final result = [...server];
    for (final op in _outbox()) {
      if (op['type'] != 'createList') continue;
      final list = SharedList.fromJson(
        Map<String, Object?>.from(op['list']! as Map),
      );
      if (list.memberEmails.contains(email.toLowerCase()) &&
          result.every((l) => l.id != list.id)) {
        result.add(list);
      }
    }
    return result..sort((a, b) => a.name.compareTo(b.name));
  }

  /// Mismo orden que en la nube: pendientes primero, luego por fecha.
  static List<SharedListItem> sortItems(List<SharedListItem> items) =>
      items..sort((a, b) {
        if (a.done != b.done) return a.done ? 1 : -1;
        return a.addedAt.compareTo(b.addedAt);
      });

  /// Combina la copia local, la nube en vivo y los cambios pendientes.
  Stream<List<T>> _merged<T>({
    required List<T>? Function() cached,
    required Stream<List<T>> Function() remote,
    required Future<void> Function(List<T> server) save,
    required List<T> Function(List<T> server) overlay,
  }) {
    late StreamController<List<T>> controller;
    StreamSubscription<List<T>>? remoteSub;
    StreamSubscription<void>? localSub;
    Timer? noAnswer;
    var server = cached();
    var emitted = false;

    void emit() {
      if (controller.isClosed) return;
      emitted = true;
      controller.add(overlay(server ?? <T>[]));
    }

    controller = StreamController<List<T>>(
      onListen: () {
        if (server != null || _outbox().isNotEmpty) emit();
        // Sin copia y sin respuesta de la nube (sin conexión): lista vacía
        // en vez de quedarse cargando.
        noAnswer = Timer(writeTimeout ~/ 3, () {
          if (!emitted) emit();
        });
        localSub = _localChanges.stream.listen((_) => emit());
        remoteSub = remote().listen(
          (items) {
            server = items;
            unawaited(save(items));
            // Llegó algo de la nube: hay conexión para subir lo pendiente.
            unawaited(flush());
            emit();
          },
          onError: (Object error) {
            AppLogger.info('Listas sin conexión: se muestra la copia ($error)');
            if (server == null) emit();
          },
        );
      },
      onCancel: () async {
        noAnswer?.cancel();
        await remoteSub?.cancel();
        await localSub?.cancel();
      },
    );
    return controller.stream;
  }

  // --- Listas ----------------------------------------------------------------

  @override
  Stream<List<SharedList>> watchLists(String email) => _merged(
    cached: () => _cachedLists(email),
    remote: () => _remote.watchLists(email),
    save: (lists) => _prefs.setString(
      _listsKey(email),
      jsonEncode([for (final l in lists) l.toJson()]),
    ),
    overlay: (server) => _overlayLists(email, server),
  );

  @override
  Stream<List<SharedListItem>> watchItems(String listId) => _merged(
    cached: () => _cachedItems(listId),
    remote: () => _remote.watchItems(listId),
    save: (items) => _prefs.setString(
      _itemsKey(listId),
      jsonEncode([for (final i in items) i.toJson()]),
    ),
    overlay: (server) => _overlayItems(listId, server),
  );

  @override
  Future<void> createList(SharedList list) => _enqueue({
    'type': 'createList',
    'listId': list.id,
    'list': list.toJson(),
  });

  @override
  Future<void> addItems(String listId, List<SharedListItem> items) async {
    final ops = [
      for (final item in items)
        {'type': 'add', 'listId': listId, 'item': item.toJson()},
    ];
    await _saveOutbox([..._outbox(), ...ops]);
    _localChanges.add(null);
    unawaited(flush());
  }

  @override
  Future<void> setItemDone(
    String listId,
    String itemId, {
    required bool done,
  }) => _enqueue({
    'type': 'done',
    'listId': listId,
    'itemId': itemId,
    'done': done,
  });

  @override
  Future<void> deleteItem(String listId, String itemId) =>
      _enqueue({'type': 'delete', 'listId': listId, 'itemId': itemId});

  @override
  Future<void> assignItem(
    String listId,
    String itemId, {
    required String? email,
    required String? name,
  }) => _enqueue({
    'type': 'assign',
    'listId': listId,
    'itemId': itemId,
    'email': email?.toLowerCase(),
    'name': name,
  });

  @override
  Future<void> deleteList(String listId) async {
    await _remote.deleteList(listId);
    await _prefs.remove(_itemsKey(listId));
    await _saveOutbox([
      for (final op in _outbox())
        if (op['listId'] != listId) op,
    ]);
    _localChanges.add(null);
  }

  @override
  Future<void> setMembers(String listId, List<String> emails) =>
      _remote.setMembers(listId, emails);

  // --- Recordatorios compartidos (siempre en línea) --------------------------

  @override
  Future<void> send(SharedReminder reminder) => _remote.send(reminder);

  @override
  Stream<List<SharedReminder>> watchInbox(String email) =>
      _remote.watchInbox(email);

  @override
  Stream<List<SharedReminder>> watchSent(String uid) => _remote.watchSent(uid);

  @override
  Future<void> setStatus(String id, SharedStatus status, {DateTime? at}) =>
      _remote.setStatus(id, status, at: at);

  /// Borra la copia local y la cola (al cerrar sesión).
  Future<void> clear() async {
    for (final key in _prefs.getKeys().toList()) {
      if (key.startsWith('sharing.cache.') || key == _outboxKey) {
        await _prefs.remove(key);
      }
    }
    _localChanges.add(null);
  }
}
