import 'package:viernes/features/sharing/domain/sharing_models.dart';

/// Nube compartida entre cuentas. Hoy Cloud Firestore:
///
/// ```text
/// shared_reminders/{id}         de una persona a otra (por correo)
/// lists/{id}                    lista con sus miembros (correos)
/// lists/{id}/items/{itemId}     elementos de la lista
/// ```
///
/// Las reglas (`firebase/firestore.rules`) solo dejan ver a quien envía, a
/// quien recibe y a los miembros de cada lista.
abstract interface class SharingRepository {
  // --- Recordatorios compartidos --------------------------------------------

  Future<void> send(SharedReminder reminder);

  /// Lo que otras personas le enviaron a [email] y aún no llega.
  Stream<List<SharedReminder>> watchInbox(String email);

  /// Lo que envió [uid], para ver si ya lo hicieron.
  Stream<List<SharedReminder>> watchSent(String uid);

  Future<void> setStatus(String id, SharedStatus status, {DateTime? at});

  // --- Listas compartidas ---------------------------------------------------

  Stream<List<SharedList>> watchLists(String email);

  Future<void> createList(SharedList list);

  Future<void> deleteList(String listId);

  Future<void> setMembers(String listId, List<String> emails);

  Stream<List<SharedListItem>> watchItems(String listId);

  Future<void> addItems(String listId, List<SharedListItem> items);

  Future<void> setItemDone(String listId, String itemId, {required bool done});

  Future<void> deleteItem(String listId, String itemId);
}
