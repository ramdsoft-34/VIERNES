import 'package:viernes/features/account/domain/app_user.dart';

/// Por qué no se pudo iniciar sesión o completar una acción de la cuenta.
enum AuthErrorCode {
  /// El usuario cerró la ventana de Google.
  cancelled,

  /// Sin internet.
  network,

  /// Falta configurar Firebase / Google (ver `docs/CUENTAS.md`).
  notConfigured,

  /// La cuenta de Google no tiene permitido entrar (p. ej. huella SHA-1 sin
  /// registrar).
  rejected,
  unknown,
}

class AuthException implements Exception {
  const AuthException(this.code, [this.detail]);

  final AuthErrorCode code;

  /// Detalle técnico para el registro, nunca para mostrar.
  final String? detail;

  @override
  String toString() => 'AuthException(${code.name}: $detail)';
}

/// Inicio de sesión. Hoy con Google sobre Firebase Auth; otros métodos
/// (correo, Apple…) serían nuevos métodos aquí.
abstract interface class AuthRepository {
  /// Falso si la app se compiló sin la configuración de Firebase.
  bool get isAvailable;

  AppUser? get currentUser;

  /// Emite el usuario actual al suscribirse y en cada cambio de sesión. La
  /// sesión se conserva entre reinicios de la app.
  Stream<AppUser?> authStateChanges();

  /// Lanza [AuthException].
  Future<AppUser> signInWithGoogle();

  Future<void> signOut();

  /// Pide confirmar la identidad con Google otra vez (necesario antes de
  /// eliminar la cuenta). Lanza [AuthException].
  Future<void> reauthenticate();

  /// Elimina el usuario de la autenticación. Llamar después de
  /// [reauthenticate] y de borrar sus datos.
  Future<void> deleteUser();
}
