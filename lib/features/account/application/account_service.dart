import 'dart:async';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:viernes/core/logging/app_logger.dart';
import 'package:viernes/features/account/domain/app_user.dart';
import 'package:viernes/features/account/domain/auth_repository.dart';
import 'package:viernes/features/settings/data/settings_repository.dart';
import 'package:viernes/features/sync/application/sync_engine.dart';
import 'package:viernes/features/sync/data/drift_sync_store.dart';
import 'package:viernes/features/sync/domain/remote_sync_source.dart';
import 'package:viernes/features/sync/domain/sync_records.dart';

/// A qué cuenta pertenecen los datos guardados en este teléfono.
class AccountBinding {
  AccountBinding(this._prefs);

  final SharedPreferences _prefs;

  static const _ownerKey = 'account.ownerUid';
  static const _welcomeKey = 'account.welcomeSeen';

  /// Nulo: datos de uso sin cuenta.
  String? get ownerUid => _prefs.getString(_ownerKey);

  Future<void> bind(String uid) => _prefs.setString(_ownerKey, uid);

  Future<void> clear() => _prefs.remove(_ownerKey);

  /// Ya se mostró la bienvenida con la opción de iniciar sesión.
  bool get welcomeSeen => _prefs.getBool(_welcomeKey) ?? false;

  Future<void> markWelcomeSeen() => _prefs.setBool(_welcomeKey, true);
}

/// Resultado de iniciar sesión.
class SignInResult {
  const SignInResult({
    required this.user,
    this.mergedLocalData = false,
    this.report,
  });

  final AppUser user;

  /// Los recordatorios que ya había en el teléfono se unieron a la cuenta.
  final bool mergedLocalData;

  /// Nulo si no se pudo sincronizar todavía (se reintenta solo).
  final SyncReport? report;
}

/// Resultado de cerrar sesión.
sealed class SignOutResult {
  const SignOutResult();
}

final class SignedOut extends SignOutResult {
  const SignedOut();
}

/// Hay cambios que no se pudieron subir (sin internet); cerrar sesión ahora
/// los perdería.
final class SignOutBlocked extends SignOutResult {
  const SignOutBlocked(this.pendingChanges);

  final int pendingChanges;
}

/// Casos de uso de la cuenta: iniciar sesión (y asociar los datos del
/// teléfono), cerrar sesión y eliminar la cuenta.
class AccountService {
  AccountService({
    required this._auth,
    required this._remote,
    required this._local,
    required this._engine,
    required this._binding,
    required this._settings,
    required this._onSettingsRestored,
    required this._onLocalDataChanged,
    required this._clientInfo,
    this._timeout = const Duration(seconds: 20),
  });

  final AuthRepository _auth;
  final RemoteSyncSource _remote;
  final DriftSyncStore _local;
  final SyncEngine _engine;
  final AccountBinding _binding;
  final SettingsRepository _settings;
  final void Function() _onSettingsRestored;
  final Future<void> Function() _onLocalDataChanged;
  final Future<Map<String, Object?>> Function() _clientInfo;
  final Duration _timeout;

  /// Lanza `AuthException` si no se pudo iniciar sesión.
  Future<SignInResult> signInWithGoogle() async {
    final user = await _auth.signInWithGoogle();
    return connect(user);
  }

  /// Asocia este teléfono con [user] y trae sus datos.
  ///
  /// - Datos de uso sin cuenta: se unen a la cuenta (no se pierde nada).
  /// - Datos de otra cuenta: se borran del teléfono antes de bajar los de
  ///   esta.
  Future<SignInResult> connect(AppUser user) =>
      _connecting ??= _connect(user).whenComplete(() => _connecting = null);

  Future<SignInResult>? _connecting;

  Future<SignInResult> _connect(AppUser user) async {
    final owner = _binding.ownerUid;
    var merged = false;
    if (owner != user.uid) {
      if (owner != null) {
        await _local.wipe();
      } else if (await _local.hasData()) {
        await _local.markAllDirty();
        merged = true;
      }
      await _engine.reset(user.uid);
      await _binding.bind(user.uid);
    }

    SyncReport? report;
    try {
      await _remote
          .saveProfile(user, client: await _clientInfo())
          .timeout(_timeout);
      await _restoreSettings(user.uid);
      report = await _engine.sync(user.uid).timeout(_timeout * 3);
    } on Object catch (error, stack) {
      AppLogger.error(
        'No se pudo sincronizar al iniciar sesión',
        error: error,
        stackTrace: stack,
      );
    }
    await _onLocalDataChanged();
    return SignInResult(user: user, mergedLocalData: merged, report: report);
  }

  /// Las preferencias de la cuenta mandan; si la cuenta es nueva, se suben
  /// las de este teléfono.
  Future<void> _restoreSettings(String uid) async {
    final cloud = await _remote.loadSettings(uid).timeout(_timeout);
    if (cloud == null) {
      await _remote.saveSettings(uid, _settings.exportForSync());
    } else {
      await _settings.importFromSync(cloud);
      _onSettingsRestored();
    }
  }

  /// Sube lo pendiente y borra los datos del teléfono. Con [force] cierra
  /// aunque queden cambios sin subir.
  Future<SignOutResult> signOut({bool force = false}) async {
    final uid = _binding.ownerUid ?? _auth.currentUser?.uid;
    if (uid != null) {
      try {
        await _engine.push(uid).timeout(_timeout);
      } on Object catch (error) {
        AppLogger.info('Cerrar sesión: no se pudo subir lo pendiente ($error)');
      }
      final pending = await _local.pendingCount();
      if (pending > 0 && !force) return SignOutBlocked(pending);
    }
    await _auth.signOut();
    await _forgetLocal(uid);
    return const SignedOut();
  }

  /// Borra la cuenta y todos sus datos, en la nube y en el teléfono. Pide
  /// confirmar con Google antes de borrar nada.
  Future<void> deleteAccount() async {
    final user = _auth.currentUser;
    if (user == null) return;
    await _auth.reauthenticate();
    await _remote.deleteAll(user.uid);
    await _auth.deleteUser();
    await _forgetLocal(user.uid);
  }

  Future<void> _forgetLocal(String? uid) async {
    await _local.wipe();
    await _binding.clear();
    if (uid != null) await _engine.reset(uid);
    await _onLocalDataChanged();
  }
}
