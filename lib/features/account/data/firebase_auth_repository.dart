import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:viernes/features/account/domain/app_user.dart';
import 'package:viernes/features/account/domain/auth_repository.dart';

/// Inicio de sesión con Google (Credential Manager de Android) sobre Firebase
/// Auth, que conserva la sesión entre reinicios.
///
/// El "Web client ID" que pide Google lo lee el plugin del recurso
/// `default_web_client_id`, que genera `google-services.json`.
class FirebaseAuthRepository implements AuthRepository {
  FirebaseAuthRepository({FirebaseAuth? auth, GoogleSignIn? google})
    : _auth = auth ?? FirebaseAuth.instance,
      _google = google ?? GoogleSignIn.instance;

  final FirebaseAuth _auth;
  final GoogleSignIn _google;
  Future<void>? _initialized;

  Future<void> _ensureInitialized() => _initialized ??= _google.initialize();

  @override
  bool get isAvailable => true;

  @override
  AppUser? get currentUser => _toAppUser(_auth.currentUser);

  @override
  Stream<AppUser?> authStateChanges() => _auth.userChanges().map(_toAppUser);

  @override
  Future<AppUser> signInWithGoogle() async {
    final credential = await _googleCredential();
    try {
      final result = await _auth.signInWithCredential(credential);
      final user = result.user;
      if (user == null) throw const AuthException(AuthErrorCode.unknown);
      return _toAppUser(user)!;
    } on FirebaseAuthException catch (e) {
      throw _fromFirebase(e);
    }
  }

  @override
  Future<void> reauthenticate() async {
    final user = _auth.currentUser;
    if (user == null) throw const AuthException(AuthErrorCode.unknown);
    final credential = await _googleCredential();
    try {
      await user.reauthenticateWithCredential(credential);
    } on FirebaseAuthException catch (e) {
      throw _fromFirebase(e);
    }
  }

  @override
  Future<void> signOut() async {
    await _ensureInitialized();
    // Sin esto, el siguiente inicio entraría directo con la misma cuenta de
    // Google sin dejar elegir otra.
    await _google.signOut();
    await _auth.signOut();
  }

  @override
  Future<void> deleteUser() async {
    try {
      await _auth.currentUser?.delete();
    } on FirebaseAuthException catch (e) {
      throw _fromFirebase(e);
    }
    await _ensureInitialized();
    await _google.disconnect();
  }

  Future<AuthCredential> _googleCredential() async {
    try {
      await _ensureInitialized();
      final account = await _google.authenticate();
      final idToken = account.authentication.idToken;
      if (idToken == null) {
        throw const AuthException(AuthErrorCode.notConfigured, 'Sin idToken');
      }
      return GoogleAuthProvider.credential(idToken: idToken);
    } on GoogleSignInException catch (e) {
      throw AuthException(switch (e.code) {
        GoogleSignInExceptionCode.canceled ||
        GoogleSignInExceptionCode.interrupted => AuthErrorCode.cancelled,
        GoogleSignInExceptionCode.clientConfigurationError ||
        GoogleSignInExceptionCode.providerConfigurationError =>
          AuthErrorCode.notConfigured,
        _ => AuthErrorCode.unknown,
      }, '${e.code.name}: ${e.description}');
    }
  }

  static AuthException _fromFirebase(FirebaseAuthException e) =>
      AuthException(switch (e.code) {
        'network-request-failed' => AuthErrorCode.network,
        'user-disabled' || 'invalid-credential' => AuthErrorCode.rejected,
        'operation-not-allowed' ||
        'app-not-authorized' => AuthErrorCode.notConfigured,
        _ => AuthErrorCode.unknown,
      }, '${e.code}: ${e.message}');

  static AppUser? _toAppUser(User? user) => user == null
      ? null
      : AppUser(
          uid: user.uid,
          email: user.email,
          displayName: user.displayName,
          photoUrl: user.photoURL,
        );
}
