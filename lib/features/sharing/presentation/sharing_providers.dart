import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:viernes/app/providers.dart';
import 'package:viernes/core/logging/app_logger.dart';
import 'package:viernes/features/account/domain/app_user.dart';
import 'package:viernes/features/account/presentation/account_providers.dart';
import 'package:viernes/features/alerts/presentation/alert_providers.dart';
import 'package:viernes/features/reminders/domain/entities/reminder_enums.dart';
import 'package:viernes/features/reminders/presentation/providers/reminder_providers.dart';
import 'package:viernes/features/sharing/application/shared_inbox.dart';
import 'package:viernes/features/sharing/data/contacts_repository.dart';
import 'package:viernes/features/sharing/data/firestore_sharing_repository.dart';
import 'package:viernes/features/sharing/data/friend_requests.dart';
import 'package:viernes/features/sharing/data/offline_sharing_repository.dart';
import 'package:viernes/features/sharing/domain/friend_invite.dart';
import 'package:viernes/features/sharing/domain/sharing_models.dart';
import 'package:viernes/features/sharing/domain/sharing_repository.dart';

/// Nube compartida directa (Firestore). En pruebas, una falsa.
final remoteSharingRepositoryProvider = Provider<SharingRepository>(
  (ref) => FirestoreSharingRepository(FirebaseFirestore.instance),
);

/// Nube compartida con copia en el teléfono: las listas funcionan sin
/// internet y los cambios se suben al volver la conexión.
final offlineSharingRepositoryProvider = Provider<OfflineSharingRepository>(
  (ref) => OfflineSharingRepository(
    ref.watch(remoteSharingRepositoryProvider),
    ref.watch(sharedPreferencesProvider),
  ),
);

/// Lo que usa la app. Solo se usa con sesión iniciada.
final sharingRepositoryProvider = Provider<SharingRepository>(
  (ref) => ref.watch(offlineSharingRepositoryProvider),
);

final contactsRepositoryProvider = Provider<ContactsRepository>(
  (ref) => ContactsRepository(ref.watch(sharedPreferencesProvider)),
);

final contactsProvider = NotifierProvider<ContactsController, List<Contact>>(
  ContactsController.new,
);

class ContactsController extends Notifier<List<Contact>> {
  @override
  List<Contact> build() => ref.watch(contactsRepositoryProvider).all();

  Future<void> save(Contact contact) async {
    await ref.read(contactsRepositoryProvider).save(contact);
    state = ref.read(contactsRepositoryProvider).all();
  }

  Future<void> remove(Contact contact) async {
    await ref.read(contactsRepositoryProvider).remove(contact);
    state = ref.read(contactsRepositoryProvider).all();
  }
}

final friendRequestsProvider = Provider<FriendRequestsRemote>(
  (ref) => FirestoreFriendRequests(FirebaseFirestore.instance),
);

final friendInvitesProvider = Provider<FriendInvites>(FriendInvites.new);

/// Resultado de aceptar una invitación.
enum InviteResult {
  /// Agregado aquí y la otra persona me agregará sola.
  added,

  /// Agregado aquí; no se pudo avisar a la otra persona (sin internet o
  /// reglas de la nube sin publicar). Tendrá que agregarme ella.
  addedOnlyHere,

  /// Es mi propia invitación.
  self,
}

/// Invitar con un enlace y aceptar invitaciones.
class FriendInvites {
  FriendInvites(this._ref);

  final Ref _ref;

  /// Mi invitación, o nula sin sesión.
  FriendInvite? mine() {
    final user = _ref.read(authStateProvider).value;
    final email = user?.email;
    if (user == null || email == null) return null;
    final name = user.displayName?.trim();
    return FriendInvite(
      name: name == null || name.isEmpty ? email.split('@').first : name,
      email: email.toLowerCase(),
    );
  }

  Future<InviteResult> accept(FriendInvite invite) async {
    final me = mine();
    if (me != null && me.email == invite.email) return InviteResult.self;
    await _ref
        .read(contactsProvider.notifier)
        .save(Contact(name: invite.name, email: invite.email));
    final user = _ref.read(authStateProvider).value;
    if (me == null || user == null) return InviteResult.addedOnlyHere;
    try {
      await _ref
          .read(friendRequestsProvider)
          .send(
            toEmail: invite.email,
            fromUid: user.uid,
            fromEmail: me.email,
            fromName: me.name,
          )
          .timeout(const Duration(seconds: 15));
      return InviteResult.added;
    } on Object catch (error) {
      AppLogger.info(
        'Invitación: no se pudo avisar a ${invite.email} ($error)',
      );
      return InviteResult.addedOnlyHere;
    }
  }
}

final sharedInboxProvider = Provider<SharedInbox>(
  (ref) => SharedInbox(
    remote: ref.watch(sharingRepositoryProvider),
    create: ref.watch(createReminderProvider).call,
    links: SharedLinks(ref.watch(sharedPreferencesProvider)),
    notifier: ref.watch(notificationServiceProvider),
    now: ref.watch(clockProvider).now,
  ),
);

AppUser? _user(Ref ref) => ref.watch(authStateProvider).value;

/// Recordatorios que envié, con su estado.
final StreamProvider<List<SharedReminder>> sentRemindersProvider =
    StreamProvider.autoDispose<List<SharedReminder>>((ref) {
      final user = _user(ref);
      if (user == null) return Stream.value(const []);
      return ref.watch(sharingRepositoryProvider).watchSent(user.uid);
    });

/// Listas de las que soy miembro.
final StreamProvider<List<SharedList>> sharedListsProvider =
    StreamProvider.autoDispose<List<SharedList>>((ref) {
      final email = _user(ref)?.email;
      if (email == null) return Stream.value(const []);
      return ref.watch(sharingRepositoryProvider).watchLists(email);
    });

final StreamProviderFamily<List<SharedListItem>, String> listItemsProvider =
    StreamProvider.autoDispose.family<List<SharedListItem>, String>(
      (ref, listId) => ref.watch(sharingRepositoryProvider).watchItems(listId),
    );

final sharingCoordinatorProvider = Provider<SharingCoordinator>((ref) {
  final coordinator = SharingCoordinator(ref);
  ref.onDispose(coordinator.dispose);
  return coordinator;
});

/// Elementos de listas que me asignaron y ya avisé.
class AssignedSeen {
  AssignedSeen(this._prefs);

  final SharedPreferences _prefs;
  static const _key = 'sharing.assignedSeen';

  Set<String> all() => (_prefs.getStringList(_key) ?? []).toSet();

  Future<void> add(Iterable<String> ids) =>
      _prefs.setStringList(_key, {...all(), ...ids}.toList());
}

/// Mientras hay sesión: recibe lo que me envían, avisa cuando completo lo
/// recibido y me avisa cuando completan lo que envié o me asignan algo en
/// una lista. También sube los cambios de listas hechos sin internet.
class SharingCoordinator with WidgetsBindingObserver {
  SharingCoordinator(this._ref);

  final Ref _ref;
  final _subscriptions = <StreamSubscription<Object?>>[];
  final _listSubscriptions = <String, StreamSubscription<Object?>>{};
  Timer? _retry;
  String? _uid;

  void start() {
    WidgetsBinding.instance.addObserver(this);
    _ref.listen<AsyncValue<AppUser?>>(
      authStateProvider,
      (previous, next) => _bind(next.value),
      fireImmediately: true,
    );
    // Reintenta subir lo pendiente de las listas cada minuto.
    _retry = Timer.periodic(const Duration(minutes: 1), (_) => _flush());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    // Otro proceso (aviso con la app cerrada) pudo cambiar las preferencias.
    unawaited(_ref.read(sharedPreferencesProvider).reload());
    _flush();
  }

  void _flush() {
    if (_uid == null) return;
    final repository = _ref.read(sharingRepositoryProvider);
    if (repository is OfflineSharingRepository) {
      unawaited(_guard(repository.flush));
    }
  }

  /// Avisa de lo que me asignaron en [list] (no al abrir la app: la primera
  /// lectura solo marca lo que ya había).
  void _watchAssignments(SharedList list, String email) {
    if (_listSubscriptions.containsKey(list.id)) return;
    final seen = AssignedSeen(_ref.read(sharedPreferencesProvider));
    var first = true;
    _listSubscriptions[list.id] = _ref
        .read(sharingRepositoryProvider)
        .watchItems(list.id)
        .listen((items) {
          final mine = [
            for (final i in items)
              if (!i.done &&
                  i.assignedTo == email.toLowerCase() &&
                  !seen.all().contains(i.id))
                i,
          ];
          if (mine.isEmpty) {
            first = false;
            return;
          }
          final silent = first;
          first = false;
          unawaited(
            _guard(() async {
              await seen.add([for (final i in mine) i.id]);
              if (silent) return;
              for (final item in mine) {
                await _ref
                    .read(notificationServiceProvider)
                    .showInfo(
                      id: 0x7D000000 + (item.id.hashCode & 0xFFFF),
                      title: 'En la lista ${list.name} te toca',
                      body: item.text,
                    );
              }
            }),
          );
        }, onError: _log);
  }

  void _bind(AppUser? user) {
    if (user?.uid == _uid) return;
    _cancel();
    _uid = user?.uid;
    final email = user?.email;
    if (user == null || email == null) return;
    final remote = _ref.read(sharingRepositoryProvider);
    final inbox = _ref.read(sharedInboxProvider);
    var firstSent = true;
    _flush();
    _subscriptions
      ..add(
        remote.watchLists(email).listen((lists) {
          for (final list in lists) {
            _watchAssignments(list, email);
          }
          final ids = {for (final l in lists) l.id};
          for (final id in _listSubscriptions.keys.toList()) {
            if (!ids.contains(id)) {
              unawaited(_listSubscriptions.remove(id)?.cancel());
            }
          }
        }, onError: _log),
      )
      ..add(
        remote
            .watchInbox(email)
            .listen(
              (items) => unawaited(_guard(() => inbox.accept(items))),
              onError: _log,
            ),
      )
      ..add(
        remote.watchSent(user.uid).listen((sent) {
          final contacts = _ref.read(contactsProvider);
          // Al abrir la app no se repiten avisos viejos.
          if (firstSent) {
            firstSent = false;
            unawaited(
              _guard(() => inbox.notifyDone(sent, contacts, silent: true)),
            );
          } else {
            unawaited(_guard(() => inbox.notifyDone(sent, contacts)));
          }
        }, onError: _log),
      )
      ..add(
        _ref
            .read(friendRequestsProvider)
            .watch(email)
            .listen(
              (requests) => unawaited(_guard(() => _addBack(requests))),
              onError: _log,
            ),
      )
      ..add(
        _ref
            .read(localReminderRepositoryProvider)
            .watchByStatus({ReminderStatus.completed})
            .listen(
              (done) => unawaited(_guard(() => inbox.reportCompleted(done))),
            ),
      );
  }

  /// Alguien aceptó mi invitación: lo agrego a mis contactos y le aviso al
  /// usuario.
  Future<void> _addBack(List<FriendRequest> requests) async {
    for (final request in requests) {
      final known = _ref
          .read(contactsProvider)
          .any((c) => c.email == request.fromEmail);
      if (!known) {
        await _ref
            .read(contactsProvider.notifier)
            .save(Contact(name: request.fromName, email: request.fromEmail));
        await _ref
            .read(notificationServiceProvider)
            .showInfo(
              id: 0x7E000000 + (request.fromEmail.hashCode & 0xFFFF),
              title: '${request.fromName} ya está en tus contactos',
              body:
                  'Aceptó tu invitación. Ya pueden compartir recordatorios '
                  'y listas.',
            );
      }
      await _ref.read(friendRequestsProvider).delete(request.id);
    }
  }

  Future<void> _guard(Future<void> Function() action) async {
    try {
      await action();
    } on Object catch (error) {
      _log(error);
    }
  }

  void _log(Object error) =>
      AppLogger.info('Compartidos: no se pudo sincronizar ($error)');

  void _cancel() {
    for (final s in [..._subscriptions, ..._listSubscriptions.values]) {
      unawaited(s.cancel());
    }
    _subscriptions.clear();
    _listSubscriptions.clear();
  }

  void dispose() {
    _retry?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _cancel();
  }
}
