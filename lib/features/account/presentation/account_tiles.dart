import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:viernes/core/extensions/context_x.dart';
import 'package:viernes/core/utils/date_x.dart';
import 'package:viernes/features/account/domain/app_user.dart';
import 'package:viernes/features/account/presentation/account_actions.dart';
import 'package:viernes/features/account/presentation/account_providers.dart';
import 'package:viernes/features/sync/presentation/sync_controller.dart';

/// Sección "Cuenta" de Ajustes: iniciar sesión o ver la cuenta, el estado de
/// la sincronización, cerrar sesión y eliminar la cuenta.
class AccountTiles extends ConsumerStatefulWidget {
  const AccountTiles({super.key});

  @override
  ConsumerState<AccountTiles> createState() => _AccountTilesState();
}

class _AccountTilesState extends ConsumerState<AccountTiles> {
  bool _busy = false;

  Future<void> _run(Future<void> Function() action) async {
    setState(() => _busy = true);
    try {
      await action();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    if (!ref.watch(authRepositoryProvider).isAvailable) {
      return ListTile(
        leading: const Icon(Icons.cloud_off_outlined),
        title: Text(l10n.accountUnavailable),
        subtitle: Text(l10n.accountUnavailableSubtitle),
      );
    }

    final user = ref.watch(authStateProvider).value;
    if (user == null) {
      return ListTile(
        leading: const Icon(Icons.account_circle_outlined),
        title: Text(l10n.accountSignedOutTitle),
        subtitle: Text(l10n.accountSignedOutSubtitle),
        trailing: _busy
            ? const SizedBox.square(
                dimension: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.login),
        onTap: _busy
            ? null
            : () => unawaited(
                _run(() => AccountActions.signIn(context, ref)),
              ),
      );
    }

    return Column(
      children: [
        ListTile(
          leading: _Avatar(user: user),
          title: Text(
            user.firstName == null
                ? (user.email ?? '')
                : l10n.accountGreeting(user.firstName!),
          ),
          subtitle: user.email == null ? null : Text(user.email!),
        ),
        const Divider(height: 1, indent: 56),
        const _SyncTile(),
        const Divider(height: 1, indent: 56),
        ListTile(
          leading: const Icon(Icons.logout),
          title: Text(l10n.accountSignOut),
          enabled: !_busy,
          onTap: () => unawaited(
            _run(() => AccountActions.signOut(context, ref)),
          ),
        ),
        const Divider(height: 1, indent: 56),
        ListTile(
          leading: Icon(
            Icons.delete_forever_outlined,
            color: context.colors.error,
          ),
          title: Text(
            l10n.accountDelete,
            style: TextStyle(color: context.colors.error),
          ),
          subtitle: Text(l10n.accountDeleteSubtitle),
          enabled: !_busy,
          onTap: () => unawaited(
            _run(() => AccountActions.deleteAccount(context, ref)),
          ),
        ),
      ],
    );
  }
}

class _SyncTile extends ConsumerWidget {
  const _SyncTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final sync = ref.watch(syncControllerProvider);
    final pending = ref.watch(pendingSyncCountProvider).value ?? 0;
    final syncing = sync.phase == SyncPhase.syncing;

    final status = switch (sync.phase) {
      SyncPhase.syncing => l10n.accountSyncing,
      SyncPhase.offline => l10n.accountOffline,
      SyncPhase.error when sync.rulesOutdated => l10n.accountSyncRules,
      SyncPhase.error => l10n.accountSyncError,
      _ when sync.lastSyncedAt == null => l10n.accountNeverSynced,
      _ when sync.rulesOutdated => l10n.accountSyncPartial(
        _when(sync.lastSyncedAt!),
      ),
      _ => l10n.accountSyncedAt(_when(sync.lastSyncedAt!)),
    };

    return ListTile(
      leading: Icon(switch (sync.phase) {
        SyncPhase.offline => Icons.cloud_off_outlined,
        SyncPhase.error => Icons.sync_problem,
        _ => Icons.cloud_done_outlined,
      }),
      title: Text(l10n.accountSyncNow),
      subtitle: Text(
        pending > 0 && !syncing
            ? '$status · ${l10n.accountPending(pending)}'
            : status,
      ),
      trailing: syncing
          ? const SizedBox.square(
              dimension: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.sync),
      onTap: syncing
          ? null
          : () => unawaited(
              ref.read(syncControllerProvider.notifier).syncNow(),
            ),
    );
  }

  static String _when(DateTime at) {
    final now = DateTime.now();
    if (at.isSameDay(now)) return 'hoy a las ${DateFormat.jm('es').format(at)}';
    return 'el ${DateFormat("d 'de' MMMM, h:mm a", 'es').format(at)}';
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.user});

  final AppUser user;

  @override
  Widget build(BuildContext context) {
    final photo = user.photoUrl;
    final initial = (user.displayName ?? user.email ?? '?').characters.first;
    return CircleAvatar(
      radius: 20,
      foregroundImage: photo == null ? null : NetworkImage(photo),
      child: Text(initial.toUpperCase()),
    );
  }
}
