import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:viernes/core/cloud/cloud.dart';
import 'package:viernes/core/logging/app_logger.dart';
import 'package:viernes/features/account/domain/app_user.dart';
import 'package:viernes/features/account/presentation/account_providers.dart';
import 'package:viernes/features/alerts/data/background_alert_handler.dart';
import 'package:viernes/features/alerts/presentation/alert_providers.dart';
import 'package:viernes/features/push/push_messages.dart';
import 'package:viernes/features/sharing/application/shared_inbox.dart';
import 'package:viernes/features/sharing/data/contacts_repository.dart';
import 'package:viernes/features/sharing/data/firestore_sharing_repository.dart';
import 'package:viernes/features/sharing/presentation/sharing_providers.dart';

/// Registro del teléfono para recibir mensajes push (Firebase Cloud
/// Messaging). Cada teléfono deja su «dirección» en `push_tokens/{token}`
/// con su correo; las funciones de la nube la usan para avisarle.
class PushTokens {
  PushTokens(this._firestore, this._messaging);

  final FirebaseFirestore _firestore;
  final FirebaseMessaging _messaging;

  DocumentReference<Map<String, dynamic>> _doc(String token) =>
      _firestore.collection('push_tokens').doc(token);

  Future<void> register(AppUser user, {String? token}) async {
    final email = user.email;
    if (email == null) return;
    final value = token ?? await _messaging.getToken();
    if (value == null) return;
    await _doc(value).set({
      'uid': user.uid,
      'email': email.toLowerCase(),
      'platform': 'android',
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Este teléfono deja de recibir avisos de la cuenta (al cerrar sesión).
  Future<void> unregister() async {
    final token = await _messaging.getToken();
    if (token == null) return;
    try {
      await _doc(token).delete();
    } on Object catch (error) {
      AppLogger.info('No se pudo borrar el registro push ($error)');
    }
    await _messaging.deleteToken();
  }
}

final pushTokensProvider = Provider<PushTokens>(
  (ref) => PushTokens(FirebaseFirestore.instance, FirebaseMessaging.instance),
);

final pushCoordinatorProvider = Provider<PushCoordinator>((ref) {
  final coordinator = PushCoordinator(ref);
  ref.onDispose(coordinator.dispose);
  return coordinator;
});

/// Mantiene el registro push al día con la sesión y muestra los avisos que
/// llegan con la app abierta.
class PushCoordinator {
  PushCoordinator(this._ref);

  final Ref _ref;
  final _subscriptions = <StreamSubscription<Object?>>[];

  void start() {
    if (!_ref.read(cloudAvailableProvider)) return;
    final messaging = FirebaseMessaging.instance;
    _ref.listen<AsyncValue<AppUser?>>(authStateProvider, (previous, next) {
      final user = next.value;
      if (user != null && user.uid != previous?.value?.uid) {
        unawaited(_register(user));
      }
    }, fireImmediately: true);
    _subscriptions
      ..add(
        messaging.onTokenRefresh.listen((token) {
          final user = _ref.read(authStateProvider).value;
          if (user != null) unawaited(_register(user, token: token));
        }),
      )
      ..add(FirebaseMessaging.onMessage.listen(_onForeground));
  }

  Future<void> _register(AppUser user, {String? token}) async {
    try {
      await _ref.read(pushTokensProvider).register(user, token: token);
    } on Object catch (error) {
      if (!isOfflineError(error)) {
        AppLogger.info('No se pudo registrar para avisos push ($error)');
      }
    }
  }

  /// Con la app abierta, los recordatorios y los «lo hizo» ya llegan por la
  /// conexión en vivo (SharingCoordinator); aquí solo las invitaciones.
  Future<void> _onForeground(RemoteMessage message) async {
    if (message.data['type'] != PushTypes.listInvite) return;
    final notice = PushNotice.from(message.data);
    if (notice == null) return;
    await _ref
        .read(notificationServiceProvider)
        .showInfo(id: notice.id, title: notice.title, body: notice.body);
  }

  void dispose() {
    for (final s in _subscriptions) {
      unawaited(s.cancel());
    }
  }
}

/// Mensajes push con la app cerrada o en segundo plano. Android ejecuta esto
/// en un proceso de Flutter aparte: un recordatorio recibido se agrega a la
/// agenda (con sus avisos) sin esperar a que se abra la app.
@pragma('vm:entry-point')
Future<void> onBackgroundPush(RemoteMessage message) async {
  BackgroundContext? context;
  try {
    await Firebase.initializeApp();
    final c = context = await BackgroundContext.open();
    final data = message.data;
    final type = data['type'] as String?;
    final contacts = ContactsRepository(c.prefs).all();
    String nameOf(String email) =>
        contacts.where((x) => x.email == email).firstOrNull?.name ?? email;

    switch (type) {
      case PushTypes.sharedReminder:
        final id = data['id'] as String?;
        if (id == null) return;
        final remote = FirestoreSharingRepository(FirebaseFirestore.instance);
        final shared = await remote.fetchShared(id);
        if (shared == null) return;
        // Agrega a la agenda, lo marca «en su agenda» y avisa.
        await SharedInbox(
          remote: remote,
          create: c.createReminder.call,
          links: SharedLinks(c.prefs),
          notifier: c.notifications,
          now: c.clock.now,
        ).accept([shared]);
      case PushTypes.sharedDone:
        final id = data['id'] as String? ?? '';
        final links = SharedLinks(c.prefs);
        if (links.notified(id)) return;
        final notice = PushNotice.from(data, nameOf: nameOf);
        if (notice == null) return;
        await c.notifications.showInfo(
          id: notice.id,
          title: notice.title,
          body: notice.body,
        );
        await links.markNotified(id);
      case PushTypes.listAssigned:
        final itemId = data['itemId'] as String? ?? '';
        final seen = AssignedSeen(c.prefs);
        if (seen.all().contains(itemId)) return;
        final notice = PushNotice.from(data);
        if (notice == null) return;
        await c.notifications.showInfo(
          id: notice.id,
          title: notice.title,
          body: notice.body,
        );
        await seen.add([itemId]);
      case PushTypes.listInvite:
        final notice = PushNotice.from(data);
        if (notice == null) return;
        await c.notifications.showInfo(
          id: notice.id,
          title: notice.title,
          body: notice.body,
        );
    }
  } on Object catch (error, stack) {
    AppLogger.error(
      'Error al recibir un mensaje push',
      error: error,
      stackTrace: stack,
    );
  } finally {
    await context?.close();
  }
}
