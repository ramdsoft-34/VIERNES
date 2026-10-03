import 'package:viernes/features/account/domain/app_user.dart';
import 'package:viernes/features/account/domain/auth_repository.dart';

/// Se usa cuando la app se compiló sin la configuración de Firebase: todo
/// funciona sin cuenta y el inicio de sesión explica qué falta.
class UnavailableAuthRepository implements AuthRepository {
  const UnavailableAuthRepository();

  @override
  bool get isAvailable => false;

  @override
  AppUser? get currentUser => null;

  @override
  Stream<AppUser?> authStateChanges() => Stream.value(null);

  @override
  Future<AppUser> signInWithGoogle() =>
      Future.error(const AuthException(AuthErrorCode.notConfigured));

  @override
  Future<void> signOut() async {}

  @override
  Future<void> reauthenticate() =>
      Future.error(const AuthException(AuthErrorCode.notConfigured));

  @override
  Future<void> deleteUser() async {}
}
