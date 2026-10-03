import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:viernes/app/router/app_shell.dart';
import 'package:viernes/app/router/routes.dart';
import 'package:viernes/features/account/presentation/welcome_screen.dart';
import 'package:viernes/features/alerts/presentation/alert_screen.dart';
import 'package:viernes/features/calendar/presentation/calendar_screen.dart';
import 'package:viernes/features/history/presentation/history_screen.dart';
import 'package:viernes/features/home/presentation/home_screen.dart';
import 'package:viernes/features/learning/presentation/learning_screen.dart';
import 'package:viernes/features/places/presentation/location_reminders_screen.dart';
import 'package:viernes/features/places/presentation/places_screen.dart';
import 'package:viernes/features/reminders/domain/entities/reminder_draft.dart';
import 'package:viernes/features/reminders/presentation/screens/reminder_editor_screen.dart';
import 'package:viernes/features/reminders/presentation/screens/reminders_screen.dart';
import 'package:viernes/features/settings/presentation/settings_screen.dart';

final rootNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'root');

/// Ruta inicial: la alerta si la app se abrió desde una notificación. Se
/// define en el arranque, antes de construir el router.
final NotifierProvider<InitialLocation, String> initialLocationProvider =
    NotifierProvider<InitialLocation, String>(InitialLocation.new);

class InitialLocation extends Notifier<String> {
  @override
  String build() => AppRoutes.home;

  // Un método (no un setter) para que la intención se lea en el arranque.
  // ignore: use_setters_to_change_properties
  void set(String location) => state = location;
}

final appRouterProvider = Provider<GoRouter>((ref) {
  final router = GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: ref.read(initialLocationProvider),
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => AppShell(shell: shell),
        branches: [
          _branch(AppRoutes.home, const HomeScreen()),
          _branch(AppRoutes.reminders, const RemindersScreen()),
          _branch(AppRoutes.calendar, const CalendarScreen()),
          _branch(AppRoutes.history, const HistoryScreen()),
          _branch(AppRoutes.settings, const SettingsScreen()),
        ],
      ),
      GoRoute(
        path: AppRoutes.welcome,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const WelcomeScreen(),
      ),
      GoRoute(
        path: AppRoutes.places,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const PlacesScreen(),
      ),
      GoRoute(
        path: AppRoutes.locationReminders,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const LocationRemindersScreen(),
      ),
      GoRoute(
        path: AppRoutes.learning,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const LearningScreen(),
      ),
      GoRoute(
        path: AppRoutes.alertPath,
        parentNavigatorKey: rootNavigatorKey,
        pageBuilder: (context, state) => MaterialPage(
          fullscreenDialog: true,
          child: AlertScreen(reminderId: state.pathParameters['id']!),
        ),
      ),
      // El editor se abre a pantalla completa, por encima de la barra inferior.
      GoRoute(
        path: AppRoutes.newReminderPath,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => ReminderEditorScreen(
          initialDate: AppRoutes.parseDateParam(
            state.uri.queryParameters['fecha'],
          ),
          // Lo que entendió Viernes cuando el usuario elige "Editar".
          initialDraft: state.extra is ReminderDraft
              ? state.extra! as ReminderDraft
              : null,
        ),
      ),
      GoRoute(
        path: AppRoutes.editReminderPath,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) =>
            ReminderEditorScreen(reminderId: state.pathParameters['id']),
      ),
    ],
  );
  ref.onDispose(router.dispose);
  return router;
});

StatefulShellBranch _branch(String path, Widget screen) => StatefulShellBranch(
  routes: [GoRoute(path: path, builder: (context, state) => screen)],
);
