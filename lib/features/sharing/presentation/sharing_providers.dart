import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
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
import 'package:viernes/features/sharing/domain/sharing_models.dart';
import 'package:viernes/features/sharing/domain/sharing_repository.dart';

/// Nube compartida. Solo se usa con sesión iniciada; en pruebas, una falsa.
final sharingRepositoryProvider = Provider<SharingRepository>(
  (ref) => FirestoreSharingRepository(FirebaseFirestore.instance),
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

/// Mientras hay sesión: recibe lo que me envían, avisa cuando completo lo
/// recibido y me avisa cuando completan lo que envié.
class SharingCoordinator {
  SharingCoordinator(this._ref);

  final Ref _ref;
  final _subscriptions = <StreamSubscription<Object?>>[];
  String? _uid;

  void start() {
    _ref.listen<AsyncValue<AppUser?>>(
      authStateProvider,
      (previous, next) => _bind(next.value),
      fireImmediately: true,
    );
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
    _subscriptions
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
            .read(localReminderRepositoryProvider)
            .watchByStatus({ReminderStatus.completed})
            .listen(
              (done) => unawaited(_guard(() => inbox.reportCompleted(done))),
            ),
      );
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
    for (final s in _subscriptions) {
      unawaited(s.cancel());
    }
    _subscriptions.clear();
  }

  void dispose() => _cancel();
}
