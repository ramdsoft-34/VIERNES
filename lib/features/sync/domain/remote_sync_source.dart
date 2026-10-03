import 'package:viernes/features/account/domain/app_user.dart';
import 'package:viernes/features/sync/domain/sync_records.dart';

/// Almacenamiento en la nube de los datos de cada cuenta.
///
/// Hoy lo implementa Cloud Firestore (`users/{uid}/...`). Cambiar de
/// proveedor es escribir otra implementación de esta interfaz.
abstract interface class RemoteSyncSource {
  /// Sube los cambios. Es idempotente: repetir la subida no duplica nada.
  Future<void> push(String uid, LocalChanges changes);

  /// Cambios hechos desde [since] (todo si es nulo).
  Future<RemoteChanges> pull(String uid, {DateTime? since});

  /// Crea o actualiza el perfil de la cuenta.
  Future<void> saveProfile(
    AppUser user, {
    required Map<String, Object?> client,
  });

  /// Preferencias guardadas en la cuenta, o nulo si nunca se subieron.
  Future<Map<String, Object?>?> loadSettings(String uid);

  Future<void> saveSettings(String uid, Map<String, Object?> settings);

  /// Borra todos los datos de la cuenta (al eliminarla).
  Future<void> deleteAll(String uid);
}
