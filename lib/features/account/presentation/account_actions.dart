import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:viernes/core/extensions/context_x.dart';
import 'package:viernes/core/logging/app_logger.dart';
import 'package:viernes/features/account/application/account_service.dart';
import 'package:viernes/features/account/domain/auth_repository.dart';
import 'package:viernes/features/account/presentation/account_providers.dart';
import 'package:viernes/l10n/gen/app_localizations.dart';

/// Acciones de la cuenta con sus mensajes, compartidas por la bienvenida y
/// los ajustes.
abstract final class AccountActions {
  /// Devuelve verdadero si se inició sesión.
  static Future<bool> signIn(BuildContext context, WidgetRef ref) async {
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    try {
      final result = await ref.read(accountServiceProvider).signInWithGoogle();
      final name = result.user.firstName ?? result.user.email ?? '';
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            result.report == null
                ? l10n.accountSignInLater
                : result.mergedLocalData
                ? l10n.accountMerged
                : l10n.accountWelcomeBack(name),
          ),
        ),
      );
      return true;
    } on AuthException catch (error) {
      AppLogger.info('Inicio de sesión fallido: $error');
      if (error.code != AuthErrorCode.cancelled) {
        messenger.showSnackBar(
          SnackBar(content: Text(authErrorMessage(l10n, error.code))),
        );
      }
      return false;
    }
  }

  static Future<void> signOut(BuildContext context, WidgetRef ref) async {
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await _confirm(
      context,
      title: l10n.accountSignOut,
      message: l10n.accountSignOutConfirm,
      action: l10n.accountSignOut,
    );
    if (!confirmed) return;
    final service = ref.read(accountServiceProvider);
    if (await service.signOut() case SignOutBlocked(:final pendingChanges)) {
      if (!context.mounted) return;
      final force = await _confirm(
        context,
        title: l10n.accountSignOut,
        message: l10n.accountSignOutBlocked(pendingChanges),
        action: l10n.accountSignOutAnyway,
        destructive: true,
      );
      if (!force) return;
      await service.signOut(force: true);
    }
    messenger.showSnackBar(SnackBar(content: Text(l10n.accountSignedOut)));
  }

  static Future<void> deleteAccount(BuildContext context, WidgetRef ref) async {
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await _confirm(
      context,
      title: l10n.accountDelete,
      message: l10n.accountDeleteConfirm,
      action: l10n.actionDelete,
      destructive: true,
    );
    if (!confirmed) return;
    try {
      await ref.read(accountServiceProvider).deleteAccount();
      messenger.showSnackBar(SnackBar(content: Text(l10n.accountDeleted)));
    } on AuthException catch (error) {
      if (error.code != AuthErrorCode.cancelled) {
        messenger.showSnackBar(
          SnackBar(content: Text(authErrorMessage(l10n, error.code))),
        );
      }
    } on Object catch (error, stack) {
      AppLogger.error(
        'No se pudo eliminar la cuenta',
        error: error,
        stackTrace: stack,
      );
      messenger.showSnackBar(SnackBar(content: Text(l10n.authErrorUnknown)));
    }
  }

  static String authErrorMessage(AppLocalizations l10n, AuthErrorCode code) =>
      switch (code) {
        AuthErrorCode.cancelled => l10n.authErrorCancelled,
        AuthErrorCode.network => l10n.authErrorNetwork,
        AuthErrorCode.notConfigured => l10n.authErrorNotConfigured,
        AuthErrorCode.rejected => l10n.authErrorRejected,
        AuthErrorCode.unknown => l10n.authErrorUnknown,
      };

  static Future<bool> _confirm(
    BuildContext context, {
    required String title,
    required String message,
    required String action,
    bool destructive = false,
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(context.l10n.actionCancel),
          ),
          FilledButton(
            style: destructive
                ? FilledButton.styleFrom(
                    backgroundColor: context.colors.error,
                    foregroundColor: context.colors.onError,
                  )
                : null,
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(action),
          ),
        ],
      ),
    );
    return confirmed ?? false;
  }
}
