import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:viernes/core/extensions/context_x.dart';
import 'package:viernes/core/widgets/liquid.dart';
import 'package:viernes/features/alerts/presentation/alert_providers.dart';

/// Pide, en orden, los permisos que faltan para que los avisos lleguen.
Future<void> requestMissingAlertPermissions(WidgetRef ref) async {
  final service = ref.read(notificationServiceProvider);
  final current = await service.checkPermissions();
  if (!current.notifications) await service.requestNotifications();
  if (!current.exactAlarms) await service.requestExactAlarms();
  if (!current.fullScreen) await service.requestFullScreen();
  ref.invalidate(alertPermissionsProvider);
  await ref.read(alertCoordinatorProvider).resyncAll();
}

/// Tarjeta en Inicio cuando falta un permiso esencial.
class AlertPermissionsBanner extends ConsumerWidget {
  const AlertPermissionsBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final permissions = ref.watch(alertPermissionsProvider).value;
    if (permissions == null || permissions.essentialsGranted) {
      return const SizedBox.shrink();
    }
    final l10n = context.l10n;
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: LiquidGlass(
        tint: colors.tertiary.withValues(alpha: 0.22),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.notifications_off_outlined,
                    color: colors.onSurface,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      l10n.permissionsBannerTitle,
                      style: context.textTheme.titleMedium,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                l10n.permissionsBannerBody,
                style: context.textTheme.bodyMedium,
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: () => unawaited(requestMissingAlertPermissions(ref)),
                child: Text(l10n.permissionsGrant),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Estado de cada permiso en Ajustes.
class AlertPermissionsTiles extends ConsumerWidget {
  const AlertPermissionsTiles({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final service = ref.read(notificationServiceProvider);
    final permissions = ref.watch(alertPermissionsProvider).value;

    Future<void> request(Future<void> Function() action) async {
      await action();
      ref.invalidate(alertPermissionsProvider);
      await ref.read(alertCoordinatorProvider).resyncAll();
    }

    return Column(
      children: [
        _PermissionTile(
          icon: Icons.notifications_outlined,
          title: l10n.permissionNotifications,
          granted: permissions?.notifications,
          onRequest: () => request(service.requestNotifications),
        ),
        const Divider(height: 1, indent: 56),
        _PermissionTile(
          icon: Icons.alarm,
          title: l10n.permissionExactAlarms,
          granted: permissions?.exactAlarms,
          onRequest: () => request(service.requestExactAlarms),
        ),
        const Divider(height: 1, indent: 56),
        _PermissionTile(
          icon: Icons.fullscreen,
          title: l10n.permissionFullScreen,
          granted: permissions?.fullScreen,
          onRequest: () => request(service.requestFullScreen),
        ),
      ],
    );
  }
}

class _PermissionTile extends StatelessWidget {
  const _PermissionTile({
    required this.icon,
    required this.title,
    required this.granted,
    required this.onRequest,
  });

  final IconData icon;
  final String title;
  final bool? granted;
  final Future<void> Function() onRequest;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final ok = granted ?? true;
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text(ok ? l10n.permissionGranted : l10n.permissionMissing),
      trailing: ok
          ? Icon(Icons.check_circle, color: context.colors.onPrimaryContainer)
          : TextButton(
              onPressed: () => unawaited(onRequest()),
              child: Text(l10n.permissionsGrant),
            ),
    );
  }
}
