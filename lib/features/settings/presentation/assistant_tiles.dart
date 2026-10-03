import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:viernes/app/router/routes.dart';
import 'package:viernes/core/extensions/context_x.dart';
import 'package:viernes/features/device/device_providers.dart';
import 'package:viernes/features/settings/domain/app_settings.dart';
import 'package:viernes/features/settings/presentation/settings_controller.dart';

/// Opciones del asistente que dependen del teléfono: calendario,
/// cumpleaños, modo conducción y botón de los audífonos.
class AssistantTiles extends ConsumerWidget {
  const AssistantTiles({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final settings = ref.watch(settingsControllerProvider);
    final controller = ref.read(settingsControllerProvider.notifier);

    return Column(
      children: [
        SwitchListTile(
          secondary: const Icon(Icons.calendar_month_outlined),
          title: Text(l10n.settingsCalendar),
          subtitle: Text(l10n.settingsCalendarSubtitle),
          value: settings.includeCalendar,
          onChanged: (enabled) =>
              unawaited(_setCalendar(context, ref, enabled: enabled)),
        ),
        const Divider(height: 1, indent: 56),
        ListTile(
          leading: const Icon(Icons.cake_outlined),
          title: Text(l10n.birthdaysTitle),
          subtitle: Text(l10n.settingsBirthdaysSubtitle),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => unawaited(context.push(AppRoutes.birthdays)),
        ),
        const Divider(height: 1, indent: 56),
        ListTile(
          leading: const Icon(Icons.directions_car_outlined),
          title: Text(l10n.settingsDriving),
          subtitle: Text(l10n.drivingMode(settings.drivingMode.name)),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => unawaited(_chooseDriving(context, ref, settings)),
        ),
        const Divider(height: 1, indent: 56),
        ListTile(
          leading: const Icon(Icons.headset_mic_outlined),
          title: Text(l10n.settingsHeadset),
          subtitle: Text(l10n.settingsHeadsetSubtitle),
          trailing: const Icon(Icons.open_in_new),
          onTap: () =>
              unawaited(ref.read(deviceDataProvider).openAssistantSettings()),
        ),
        const Divider(height: 1, indent: 56),
        SwitchListTile(
          secondary: const Icon(Icons.record_voice_over_outlined),
          title: Text(l10n.settingsSpeakBriefing),
          subtitle: Text(l10n.settingsSpeakBriefingSubtitle),
          value: settings.speakBriefing,
          onChanged: (v) =>
              controller.update((s) => s.copyWith(speakBriefing: v)),
        ),
      ],
    );
  }

  Future<void> _setCalendar(
    BuildContext context,
    WidgetRef ref, {
    required bool enabled,
  }) async {
    final controller = ref.read(settingsControllerProvider.notifier);
    if (!enabled) {
      controller.update((s) => s.copyWith(includeCalendar: false));
      return;
    }
    final messenger = ScaffoldMessenger.of(context);
    final l10n = context.l10n;
    final device = ref.read(deviceDataProvider);
    final granted =
        await device.hasCalendarPermission() ||
        await device.requestCalendarPermission();
    if (granted) {
      controller.update((s) => s.copyWith(includeCalendar: true));
    } else {
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.settingsCalendarDenied)),
      );
    }
  }

  Future<void> _chooseDriving(
    BuildContext context,
    WidgetRef ref,
    AppSettings settings,
  ) async {
    final l10n = context.l10n;
    final picked = await showDialog<DrivingMode>(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text(l10n.settingsDriving),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
            child: Text(l10n.settingsDrivingHelp),
          ),
          RadioGroup<DrivingMode>(
            groupValue: settings.drivingMode,
            onChanged: (mode) => Navigator.of(context).pop(mode),
            child: Column(
              children: [
                for (final mode in DrivingMode.values)
                  RadioListTile<DrivingMode>(
                    value: mode,
                    title: Text(l10n.drivingMode(mode.name)),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
    if (picked == null) return;
    ref
        .read(settingsControllerProvider.notifier)
        .update((s) => s.copyWith(drivingMode: picked));
    // Para saber si hay un carro conectado por Bluetooth (Android 12+).
    if (picked == DrivingMode.auto) {
      await ref.read(deviceDataProvider).requestBluetoothPermission();
    }
  }
}
