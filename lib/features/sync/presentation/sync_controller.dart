import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:viernes/app/providers.dart';
import 'package:viernes/core/cloud/cloud.dart';
import 'package:viernes/core/logging/app_logger.dart';
import 'package:viernes/features/account/domain/app_user.dart';
import 'package:viernes/features/account/presentation/account_providers.dart';
import 'package:viernes/features/attachments/presentation/attachment_providers.dart';
import 'package:viernes/features/settings/domain/app_settings.dart';
import 'package:viernes/features/settings/presentation/settings_controller.dart';
import 'package:viernes/features/sync/application/sync_engine.dart';
import 'package:viernes/features/sync/data/drift_sync_store.dart';
import 'package:viernes/features/sync/data/firestore_sync_source.dart';
import 'package:viernes/features/sync/domain/remote_sync_source.dart';

final syncStoreProvider = Provider<DriftSyncStore>(
  (ref) => DriftSyncStore(ref.watch(appDatabaseProvider)),
);

/// Nube de datos. Solo se usa si [cloudAvailableProvider] es verdadero; en
/// pruebas se sobrescribe con una falsa.
final remoteSyncSourceProvider = Provider<RemoteSyncSource>(
  (ref) => FirestoreSyncSource(FirebaseFirestore.instance),
);

final syncEngineProvider = Provider<SyncEngine>(
  (ref) => SyncEngine(
    local: ref.watch(syncStoreProvider),
    remote: ref.watch(remoteSyncSourceProvider),
    cursors: SyncCursorStore(ref.watch(sharedPreferencesProvider)),
  ),
);

/// Cambios del teléfono que aún no llegan a la cuenta.
final pendingSyncCountProvider = StreamProvider<int>(
  (ref) => ref.watch(syncStoreProvider).watchPendingCount(),
);

enum SyncPhase {
  /// La app no tiene cuentas configuradas o no hay sesión.
  inactive,
  idle,
  syncing,

  /// Sin internet; se reintenta solo.
  offline,
  error,
}

@immutable
class SyncState {
  const SyncState({
    this.phase = SyncPhase.inactive,
    this.lastSyncedAt,
    this.rulesOutdated = false,
  });

  final SyncPhase phase;
  final DateTime? lastSyncedAt;

  /// La nube rechazó algo por permisos: las reglas de seguridad publicadas
  /// son de una versión anterior (ver docs/CUENTAS.md). Con [SyncPhase.idle]
  /// significa que lo principal se sincronizó pero los lugares no.
  final bool rulesOutdated;

  SyncState copyWith({
    SyncPhase? phase,
    DateTime? lastSyncedAt,
    bool? rulesOutdated,
  }) => SyncState(
    phase: phase ?? this.phase,
    lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
    rulesOutdated: rulesOutdated ?? this.rulesOutdated,
  );
}

final syncControllerProvider = NotifierProvider<SyncController, SyncState>(
  SyncController.new,
);

/// Decide cuándo sincronizar: al iniciar sesión, al abrir la app, al volver
/// a ella, poco después de cada cambio local y a pedido del usuario.
class SyncController extends Notifier<SyncState> with WidgetsBindingObserver {
  static const _lastSyncKey = 'sync.lastSyncedAt';

  /// Agrupa varios cambios seguidos en una sola subida.
  static const _debounce = Duration(seconds: 3);
  static const _retry = Duration(minutes: 2);
  static const _timeout = Duration(seconds: 45);

  Timer? _timer;
  Timer? _settingsTimer;
  Future<void>? _running;
  bool _again = false;

  @override
  SyncState build() {
    if (!ref.watch(cloudAvailableProvider)) return const SyncState();

    final lifecycle = WidgetsBinding.instance..addObserver(this);
    ref
      ..listen<AsyncValue<AppUser?>>(authStateProvider, (previous, next) {
        if (next.value != null) unawaited(syncNow());
      })
      ..listen<AsyncValue<int>>(pendingSyncCountProvider, (previous, next) {
        if ((next.value ?? 0) > 0) _schedule(_debounce);
      })
      ..listen<AppSettings>(settingsControllerProvider, (previous, next) {
        if (previous != null) _scheduleSettingsUpload();
      })
      ..onDispose(() {
        _timer?.cancel();
        _settingsTimer?.cancel();
        lifecycle.removeObserver(this);
      });

    final last = ref.read(sharedPreferencesProvider).getInt(_lastSyncKey);
    return SyncState(
      lastSyncedAt: last == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(last),
    );
  }

  /// Arranca la primera sincronización si ya había sesión.
  void start() => _schedule(Duration.zero);

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _schedule(Duration.zero);
  }

  void _schedule(Duration delay) {
    _timer?.cancel();
    _timer = Timer(delay, () => unawaited(syncNow()));
  }

  /// Sube lo pendiente y baja lo nuevo. Si ya hay una en curso, se repite
  /// al terminar.
  Future<void> syncNow() async {
    final running = _running;
    if (running != null) {
      _again = true;
      return running;
    }
    final future = _run();
    _running = future;
    try {
      await future;
    } finally {
      _running = null;
    }
    if (_again) {
      _again = false;
      await syncNow();
    }
  }

  Future<void> _run() async {
    final user = ref.read(authRepositoryProvider).currentUser;
    if (user == null) {
      state = state.copyWith(phase: SyncPhase.inactive);
      return;
    }
    state = state.copyWith(phase: SyncPhase.syncing);
    var rulesOutdated = false;
    try {
      final binding = ref.read(accountBindingProvider);
      if (binding.ownerUid != user.uid) {
        // Sesión que aún no se asoció a este teléfono (p. ej. al actualizar
        // la app con la sesión ya abierta).
        await ref.read(accountServiceProvider).connect(user);
      } else {
        final report = await ref
            .read(syncEngineProvider)
            .sync(user.uid)
            .timeout(_timeout);
        if (report.downloaded > 0) {
          await ref.read(localDataChangedProvider)();
        }
        rulesOutdated = report.skipped.isNotEmpty;
        if (rulesOutdated) {
          AppLogger.info(
            'Sincronización parcial: la nube rechazó ${report.skipped} '
            '(reglas de Firestore sin publicar)',
          );
        }
      }
      await _syncAttachments(user.uid);
      final now = DateTime.now();
      unawaited(
        ref
            .read(sharedPreferencesProvider)
            .setInt(_lastSyncKey, now.millisecondsSinceEpoch),
      );
      if (!ref.mounted) return;
      state = SyncState(
        phase: SyncPhase.idle,
        lastSyncedAt: now,
        rulesOutdated: rulesOutdated,
      );
    } on Object catch (error, stack) {
      if (!ref.mounted) return;
      final offline = isOfflineError(error);
      if (!offline) {
        AppLogger.error(
          'Falló la sincronización',
          error: error,
          stackTrace: stack,
        );
      }
      state = state.copyWith(
        phase: offline ? SyncPhase.offline : SyncPhase.error,
        rulesOutdated: isPermissionError(error),
      );
      _schedule(_retry);
    }
  }

  /// Fotos y notas de voz. Si fallan (p. ej. Storage sin activar), los
  /// recordatorios ya quedaron sincronizados.
  Future<void> _syncAttachments(String uid) async {
    try {
      await ref.read(attachmentSyncProvider).sync(uid).timeout(_timeout * 2);
    } on Object catch (error) {
      if (!isOfflineError(error)) {
        AppLogger.info('Adjuntos: no se pudieron sincronizar ($error)');
      }
    }
  }

  void _scheduleSettingsUpload() {
    _settingsTimer?.cancel();
    _settingsTimer = Timer(_debounce, () async {
      final uid = ref.read(authRepositoryProvider).currentUser?.uid;
      if (uid == null || ref.read(accountBindingProvider).ownerUid != uid) {
        return;
      }
      try {
        await ref
            .read(remoteSyncSourceProvider)
            .saveSettings(
              uid,
              ref.read(settingsRepositoryProvider).exportForSync(),
            )
            .timeout(_timeout);
      } on Object catch (error) {
        AppLogger.info('No se pudieron subir las preferencias ($error)');
      }
    });
  }
}
