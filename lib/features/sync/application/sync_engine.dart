import 'package:shared_preferences/shared_preferences.dart';
import 'package:viernes/features/sync/data/drift_sync_store.dart';
import 'package:viernes/features/sync/domain/remote_sync_source.dart';
import 'package:viernes/features/sync/domain/sync_records.dart';

/// Recuerda hasta dónde se descargó cada cuenta.
class SyncCursorStore {
  SyncCursorStore(this._prefs);

  final SharedPreferences _prefs;

  static String _key(String uid) => 'sync.cursor.$uid';

  DateTime? read(String uid) {
    final value = _prefs.getInt(_key(uid));
    return value == null ? null : DateTime.fromMillisecondsSinceEpoch(value);
  }

  Future<void> write(String uid, DateTime cursor) =>
      _prefs.setInt(_key(uid), cursor.millisecondsSinceEpoch);

  Future<void> clear(String uid) => _prefs.remove(_key(uid));
}

/// Sincroniza la base local con la cuenta: primero sube lo pendiente y luego
/// descarga lo que cambió en otros teléfonos.
///
/// La base local sigue siendo la fuente de verdad de la app (funciona sin
/// internet); la nube es el respaldo y el puente entre teléfonos.
class SyncEngine {
  SyncEngine({
    required this._local,
    required this._remote,
    required this._cursors,
  });

  final DriftSyncStore _local;
  final RemoteSyncSource _remote;
  final SyncCursorStore _cursors;

  /// Una sincronización a la vez: las llamadas se encolan.
  Future<void> _tail = Future.value();

  Future<T> _exclusive<T>(Future<T> Function() action) {
    final result = _tail.then((_) => action());
    _tail = result.then<void>((_) {}, onError: (Object _) {});
    return result;
  }

  Future<SyncReport> sync(String uid) => _exclusive(() async {
    final uploaded = await _push(uid);
    final changes = await _remote.pull(uid, since: _cursors.read(uid));
    final downloaded = changes.isEmpty ? 0 : await _local.applyRemote(changes);
    final cursor = changes.cursor;
    if (cursor != null) await _cursors.write(uid, cursor);
    return SyncReport(uploaded: uploaded, downloaded: downloaded);
  });

  /// Sube los cambios pendientes. Devuelve cuántos se subieron.
  Future<int> push(String uid) => _exclusive(() => _push(uid));

  Future<int> _push(String uid) async {
    final changes = await _local.pendingChanges();
    if (changes.isEmpty) return 0;
    await _remote.push(uid, changes);
    await _local.markUploaded(changes);
    return changes.length;
  }

  /// Olvida el progreso de descarga (la próxima vez baja todo).
  Future<void> reset(String uid) => _cursors.clear(uid);
}
