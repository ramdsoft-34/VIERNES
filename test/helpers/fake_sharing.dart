import 'dart:async';

import 'package:viernes/features/sharing/application/shared_inbox.dart';
import 'package:viernes/features/sharing/domain/sharing_models.dart';
import 'package:viernes/features/sharing/domain/sharing_repository.dart';

/// Nube compartida en memoria.
class FakeSharingRepository implements SharingRepository {
  final shared = <String, SharedReminder>{};
  final lists = <String, SharedList>{};
  final items = <String, Map<String, SharedListItem>>{};
  final _changes = StreamController<void>.broadcast();

  void _changed() => _changes.add(null);

  Stream<T> _watch<T>(T Function() read) async* {
    yield read();
    yield* _changes.stream.map((_) => read());
  }

  @override
  Future<void> send(SharedReminder reminder) async {
    shared[reminder.id] = reminder;
    _changed();
  }

  @override
  Stream<List<SharedReminder>> watchInbox(String email) => _watch(
    () => [
      for (final r in shared.values)
        if (r.toEmail == email && r.status == SharedStatus.sent) r,
    ],
  );

  @override
  Stream<List<SharedReminder>> watchSent(String uid) => _watch(
    () => [
      for (final r in shared.values)
        if (r.fromUid == uid) r,
    ],
  );

  @override
  Future<void> setStatus(String id, SharedStatus status, {DateTime? at}) async {
    shared[id] = shared[id]!.copyWith(status: status, doneAt: at);
    _changed();
  }

  @override
  Stream<List<SharedList>> watchLists(String email) => _watch(
    () => [
      for (final l in lists.values)
        if (l.memberEmails.contains(email)) l,
    ],
  );

  @override
  Future<void> createList(SharedList list) async {
    lists[list.id] = list;
    _changed();
  }

  @override
  Future<void> deleteList(String listId) async {
    lists.remove(listId);
    items.remove(listId);
    _changed();
  }

  @override
  Future<void> setMembers(String listId, List<String> emails) async {
    final l = lists[listId]!;
    lists[listId] = SharedList(
      id: l.id,
      name: l.name,
      ownerUid: l.ownerUid,
      memberEmails: emails,
      createdAt: l.createdAt,
    );
    _changed();
  }

  @override
  Stream<List<SharedListItem>> watchItems(String listId) =>
      _watch(() => (items[listId] ?? {}).values.toList());

  @override
  Future<void> addItems(String listId, List<SharedListItem> newItems) async {
    final map = items.putIfAbsent(listId, () => {});
    for (final item in newItems) {
      map[item.id] = item;
    }
    _changed();
  }

  @override
  Future<void> setItemDone(
    String listId,
    String itemId, {
    required bool done,
  }) async {
    final item = items[listId]![itemId]!;
    items[listId]![itemId] = item.copyWith(done: done);
    _changed();
  }

  @override
  Future<void> assignItem(
    String listId,
    String itemId, {
    required String? email,
    required String? name,
  }) async {
    final item = items[listId]![itemId]!;
    items[listId]![itemId] = email == null
        ? item.copyWith(clearAssignee: true)
        : item.copyWith(assignedTo: email, assignedName: name);
    _changed();
  }

  @override
  Future<void> deleteItem(String listId, String itemId) async {
    items[listId]?.remove(itemId);
    _changed();
  }
}

class FakeInfoNotifier implements InfoNotifier {
  final shown = <(String, String)>[];

  @override
  Future<void> showInfo({
    required int id,
    required String title,
    required String body,
  }) async => shown.add((title, body));
}
