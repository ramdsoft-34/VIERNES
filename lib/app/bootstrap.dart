import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:viernes/ai/ai_providers.dart';
import 'package:viernes/app/app.dart';
import 'package:viernes/app/flavor.dart';
import 'package:viernes/app/providers.dart';
import 'package:viernes/app/router/app_router.dart';
import 'package:viernes/app/router/routes.dart';
import 'package:viernes/core/cloud/cloud.dart';
import 'package:viernes/core/logging/app_logger.dart';
import 'package:viernes/features/account/presentation/account_providers.dart';
import 'package:viernes/features/alerts/application/alert_action_handler.dart';
import 'package:viernes/features/alerts/presentation/alert_providers.dart';
import 'package:viernes/features/places/presentation/places_providers.dart';
import 'package:viernes/features/sharing/presentation/sharing_providers.dart';
import 'package:viernes/features/sync/presentation/sync_controller.dart';
import 'package:viernes/features/voice_assistant/presentation/wake_word_controller.dart';

/// Arranque común a todas las versiones de la app.
Future<void> bootstrap(AppFlavor flavor) async {
  WidgetsFlutterBinding.ensureInitialized();

  FlutterError.onError = (details) {
    AppLogger.error(
      'Error de Flutter',
      error: details.exception,
      stackTrace: details.stack,
    );
    FlutterError.presentError(details);
  };
  PlatformDispatcher.instance.onError = (error, stackTrace) {
    AppLogger.error(
      'Error no controlado',
      error: error,
      stackTrace: stackTrace,
    );
    return true;
  };

  Intl.defaultLocale = 'es';
  await initializeDateFormatting('es');
  final prefs = await SharedPreferences.getInstance();
  final cloudAvailable = await initializeCloud();

  final container = ProviderContainer(
    overrides: [
      cloudAvailableProvider.overrideWithValue(cloudAvailable),
      flavorProvider.overrideWithValue(flavor),
      sharedPreferencesProvider.overrideWithValue(prefs),
    ],
  );

  // Primera apertura: invitar a iniciar sesión. Si la app se abrió desde un
  // aviso, la alerta tiene prioridad (se define abajo).
  if (container.read(shouldShowWelcomeProvider)) {
    container.read(initialLocationProvider.notifier).set(AppRoutes.welcome);
  }

  // Si la app se abrió desde un aviso, arranca directo en la alerta.
  try {
    final launch = await container
        .read(notificationServiceProvider)
        .initialize();
    final reminderId = launch?.payload;
    // Los resúmenes diarios abren el inicio, que ya es la ruta por defecto.
    if (reminderId != null &&
        launch?.actionId == null &&
        !reminderId.startsWith(AlertActions.summaryPayloadPrefix)) {
      container
          .read(initialLocationProvider.notifier)
          .set(AppRoutes.alert(reminderId));
    }
  } on Object catch (error, stack) {
    AppLogger.error(
      'No se pudieron iniciar las notificaciones',
      error: error,
      stackTrace: stack,
    );
  }
  container.read(alertCoordinatorProvider).start();
  container.read(wakeCoordinatorProvider).start();
  container.read(syncControllerProvider.notifier).start();
  unawaited(container.read(placesCoordinatorProvider).start());
  container.read(sharingCoordinatorProvider).start();
  // Carga la red neuronal propia en segundo plano.
  unawaited(container.read(neuralTaggerProvider.future));

  AppLogger.info('Iniciando Viernes (${flavor.name})');
  runApp(
    UncontrolledProviderScope(container: container, child: const ViernesApp()),
  );
}
