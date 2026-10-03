import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:viernes/app/providers.dart';
import 'package:viernes/core/cloud/cloud.dart';
import 'package:viernes/features/account/application/account_service.dart';
import 'package:viernes/features/account/data/firebase_auth_repository.dart';
import 'package:viernes/features/account/data/unavailable_auth_repository.dart';
import 'package:viernes/features/account/domain/app_user.dart';
import 'package:viernes/features/account/domain/auth_repository.dart';
import 'package:viernes/features/alerts/presentation/alert_providers.dart';
import 'package:viernes/features/attachments/presentation/attachment_providers.dart';
import 'package:viernes/features/push/push_service.dart';
import 'package:viernes/features/settings/presentation/settings_controller.dart';
import 'package:viernes/features/sharing/data/offline_sharing_repository.dart';
import 'package:viernes/features/sharing/presentation/sharing_providers.dart';
import 'package:viernes/features/sync/presentation/sync_controller.dart';

/// Inicio de sesión. Sin configuración de Firebase, uno que explica qué
/// falta; en pruebas, uno falso.
final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => ref.watch(cloudAvailableProvider)
      ? FirebaseAuthRepository()
      : const UnavailableAuthRepository(),
);

/// Usuario con sesión iniciada (nulo si se usa sin cuenta).
final authStateProvider = StreamProvider<AppUser?>(
  (ref) => ref.watch(authRepositoryProvider).authStateChanges(),
);

final accountBindingProvider = Provider<AccountBinding>(
  (ref) => AccountBinding(ref.watch(sharedPreferencesProvider)),
);

/// Qué hacer cuando los datos del teléfono cambiaron por la cuenta (al
/// bajar cambios, iniciar o cerrar sesión): reprogramar avisos, resúmenes y
/// widget.
final localDataChangedProvider = Provider<Future<void> Function()>(
  (ref) =>
      () => ref.read(alertCoordinatorProvider).resyncAll(),
);

final accountServiceProvider = Provider<AccountService>(
  (ref) => AccountService(
    auth: ref.watch(authRepositoryProvider),
    remote: ref.watch(remoteSyncSourceProvider),
    local: ref.watch(syncStoreProvider),
    engine: ref.watch(syncEngineProvider),
    binding: ref.watch(accountBindingProvider),
    settings: ref.watch(settingsRepositoryProvider),
    onSettingsRestored: () =>
        ref.read(settingsControllerProvider.notifier).reload(),
    onLocalDataChanged: () => ref.read(localDataChangedProvider)(),
    clientInfo: () async {
      final info = await PackageInfo.fromPlatform();
      return {
        'platform': 'android',
        'appVersion': '${info.version}+${info.buildNumber}',
        'flavor': ref.read(flavorProvider).name,
      };
    },
    beforeSignOut: (uid) => ref.read(pushTokensProvider).unregister(),
    afterSignOut: () async {
      final sharing = ref.read(sharingRepositoryProvider);
      if (sharing is OfflineSharingRepository) await sharing.clear();
      await ref.read(attachmentFilesProvider).clear();
    },
  ),
);

/// Mostrar la bienvenida con "Continuar con Google" al abrir la app.
final shouldShowWelcomeProvider = Provider<bool>(
  (ref) =>
      ref.watch(cloudAvailableProvider) &&
      ref.read(authRepositoryProvider).currentUser == null &&
      !ref.read(accountBindingProvider).welcomeSeen,
);
