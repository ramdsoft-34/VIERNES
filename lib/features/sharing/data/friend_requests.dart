import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:viernes/features/sharing/domain/friend_invite.dart';

/// Solicitudes para agregarse de vuelta.
///
/// ```text
/// friend_requests/{id}  { toEmail, fromUid, fromEmail, fromName, createdAt }
/// ```
///
/// Las crea quien acepta una invitación; solo las lee y borra el destinatario
/// (ver `firebase/firestore.rules`).
abstract interface class FriendRequestsRemote {
  Future<void> send({
    required String toEmail,
    required String fromUid,
    required String fromEmail,
    required String fromName,
  });

  Stream<List<FriendRequest>> watch(String myEmail);

  Future<void> delete(String id);
}

class FirestoreFriendRequests implements FriendRequestsRemote {
  FirestoreFriendRequests(this._firestore);

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _requests =>
      _firestore.collection('friend_requests');

  @override
  Future<void> send({
    required String toEmail,
    required String fromUid,
    required String fromEmail,
    required String fromName,
  }) => _requests.add({
    'toEmail': toEmail.toLowerCase(),
    'fromUid': fromUid,
    'fromEmail': fromEmail.toLowerCase(),
    'fromName': fromName,
    'createdAt': FieldValue.serverTimestamp(),
  });

  @override
  Stream<List<FriendRequest>> watch(String myEmail) => _requests
      .where('toEmail', isEqualTo: myEmail.toLowerCase())
      .snapshots()
      .map(
        (snapshot) => [
          for (final doc in snapshot.docs)
            if (doc.data()['fromEmail'] case final String email)
              FriendRequest(
                id: doc.id,
                fromEmail: email,
                fromName: doc.data()['fromName'] as String? ?? email,
              ),
        ],
      );

  @override
  Future<void> delete(String id) => _requests.doc(id).delete();
}
