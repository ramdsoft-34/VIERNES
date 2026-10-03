import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:viernes/core/utils/enum_x.dart';
import 'package:viernes/features/sharing/domain/sharing_models.dart';
import 'package:viernes/features/sharing/domain/sharing_repository.dart';

class FirestoreSharingRepository implements SharingRepository {
  FirestoreSharingRepository(this._firestore);

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _shared =>
      _firestore.collection('shared_reminders');

  CollectionReference<Map<String, dynamic>> get _lists =>
      _firestore.collection('lists');

  // --- Recordatorios compartidos --------------------------------------------

  @override
  Future<void> send(SharedReminder r) => _shared.doc(r.id).set({
    'fromUid': r.fromUid,
    'fromName': r.fromName,
    'fromEmail': r.fromEmail.toLowerCase(),
    'toEmail': r.toEmail.toLowerCase(),
    'title': r.title,
    'dueAt': Timestamp.fromDate(r.dueAt),
    'leadTimeMinutes': r.leadTime.inMinutes,
    'createdAt': Timestamp.fromDate(r.createdAt),
    'status': r.status.name,
  });

  @override
  Stream<List<SharedReminder>> watchInbox(String email) => _shared
      .where('toEmail', isEqualTo: email.toLowerCase())
      .where('status', isEqualTo: SharedStatus.sent.name)
      .snapshots()
      .map((s) => [for (final d in s.docs) _reminder(d.id, d.data())]);

  @override
  Stream<List<SharedReminder>> watchSent(String uid) => _shared
      .where('fromUid', isEqualTo: uid)
      .snapshots()
      .map(
        (s) =>
            [for (final d in s.docs) _reminder(d.id, d.data())]
              ..sort((a, b) => b.createdAt.compareTo(a.createdAt)),
      );

  @override
  Future<void> setStatus(String id, SharedStatus status, {DateTime? at}) =>
      _shared.doc(id).update({
        'status': status.name,
        if (status == SharedStatus.done && at != null)
          'doneAt': Timestamp.fromDate(at),
      });

  static SharedReminder _reminder(String id, Map<String, dynamic> d) =>
      SharedReminder(
        id: id,
        fromUid: d['fromUid'] as String? ?? '',
        fromName: d['fromName'] as String? ?? '',
        fromEmail: d['fromEmail'] as String? ?? '',
        toEmail: d['toEmail'] as String? ?? '',
        title: d['title'] as String? ?? '',
        dueAt: _date(d['dueAt']),
        leadTime: Duration(
          minutes: (d['leadTimeMinutes'] as num?)?.toInt() ?? 0,
        ),
        createdAt: _date(d['createdAt']),
        status: enumByName(
          SharedStatus.values,
          d['status'] as String? ?? '',
          SharedStatus.sent,
        ),
        doneAt: d['doneAt'] == null ? null : _date(d['doneAt']),
      );

  // --- Listas ---------------------------------------------------------------

  @override
  Stream<List<SharedList>> watchLists(String email) => _lists
      .where('memberEmails', arrayContains: email.toLowerCase())
      .snapshots()
      .map(
        (s) =>
            [for (final d in s.docs) _list(d.id, d.data())]
              ..sort((a, b) => a.name.compareTo(b.name)),
      );

  @override
  Future<void> createList(SharedList list) => _lists.doc(list.id).set({
    'name': list.name,
    'ownerUid': list.ownerUid,
    'memberEmails': [for (final e in list.memberEmails) e.toLowerCase()],
    'createdAt': Timestamp.fromDate(list.createdAt),
  });

  @override
  Future<void> deleteList(String listId) async {
    final items = await _lists.doc(listId).collection('items').get();
    final batch = _firestore.batch();
    for (final doc in items.docs) {
      batch.delete(doc.reference);
    }
    batch.delete(_lists.doc(listId));
    await batch.commit();
  }

  @override
  Future<void> setMembers(String listId, List<String> emails) =>
      _lists.doc(listId).update({
        'memberEmails': [for (final e in emails) e.toLowerCase()],
      });

  @override
  Stream<List<SharedListItem>> watchItems(String listId) => _lists
      .doc(listId)
      .collection('items')
      .snapshots()
      .map(
        (s) =>
            [
              for (final d in s.docs)
                SharedListItem(
                  id: d.id,
                  text: d.data()['text'] as String? ?? '',
                  addedBy: d.data()['addedBy'] as String? ?? '',
                  addedAt: _date(d.data()['addedAt']),
                  done: d.data()['done'] == true,
                ),
            ]..sort((a, b) {
              if (a.done != b.done) return a.done ? 1 : -1;
              return a.addedAt.compareTo(b.addedAt);
            }),
      );

  @override
  Future<void> addItems(String listId, List<SharedListItem> items) async {
    final batch = _firestore.batch();
    for (final item in items) {
      batch.set(_lists.doc(listId).collection('items').doc(item.id), {
        'text': item.text,
        'addedBy': item.addedBy,
        'addedAt': Timestamp.fromDate(item.addedAt),
        'done': item.done,
      });
    }
    await batch.commit();
  }

  @override
  Future<void> setItemDone(
    String listId,
    String itemId, {
    required bool done,
  }) => _lists.doc(listId).collection('items').doc(itemId).update({
    'done': done,
  });

  @override
  Future<void> deleteItem(String listId, String itemId) =>
      _lists.doc(listId).collection('items').doc(itemId).delete();

  static SharedList _list(String id, Map<String, dynamic> d) => SharedList(
    id: id,
    name: d['name'] as String? ?? '',
    ownerUid: d['ownerUid'] as String? ?? '',
    memberEmails: [
      for (final e in (d['memberEmails'] as List?) ?? const []) '$e',
    ],
    createdAt: _date(d['createdAt']),
  );

  static DateTime _date(Object? value) => switch (value) {
    final Timestamp t => t.toDate(),
    final DateTime d => d,
    _ => DateTime.fromMillisecondsSinceEpoch(0),
  };
}
