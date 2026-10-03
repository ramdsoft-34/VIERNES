import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:viernes/ai/ai_providers.dart';
import 'package:viernes/app/providers.dart';
import 'package:viernes/app/router/routes.dart';
import 'package:viernes/core/extensions/context_x.dart';
import 'package:viernes/core/widgets/liquid.dart';
import 'package:viernes/core/widgets/section_header.dart';
import 'package:viernes/features/account/presentation/account_tiles.dart';
import 'package:viernes/features/alerts/presentation/permissions_widgets.dart';
import 'package:viernes/features/reminders/presentation/reminder_formatters.dart';
import 'package:viernes/features/settings/domain/app_settings.dart';
import 'package:viernes/features/settings/presentation/assistant_tiles.dart';
import 'package:viernes/features/settings/presentation/settings_controller.dart';
import 'package:viernes/features/summaries/presentation/add_widget_tile.dart';
import 'package:viernes/features/voice_assistant/presentation/wake_word_settings.dart';

final FutureProvider<PackageInfo> _packageInfoProvider =
    FutureProvider.autoDispose<PackageInfo>(
      (ref) => PackageInfo.fromPlatform(),
    );

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final settings = ref.watch(settingsControllerProvider);
    final controller = ref.read(settingsControllerProvider.notifier);
    void update(AppSettings Function(AppSettings s) change) =>
        controller.update(change);

    return LiquidScaffold(
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: EdgeInsets.fromLTRB(
            16,
            8,
            16,
            24 + MediaQuery.paddingOf(context).bottom,
          ),
          children: [
            LiquidHeader(title: l10n.navSettings),
            SectionHeader.compact(l10n.accountSection),
            const _Group(children: [AccountTiles()]),
            SectionHeader.compact(l10n.settingsSectionReminders),
            _Group(
              children: [
                _DurationTile(
                  icon: Icons.notifications_active_outlined,
                  title: l10n.settingsDefaultLeadTime,
                  value: settings.defaultLeadTime,
                  options: AppSettings.leadTimeOptions,
                  label: l10n.leadTime,
                  onChanged: (v) =>
                      update((s) => s.copyWith(defaultLeadTime: v)),
                ),
                _DurationTile(
                  icon: Icons.snooze,
                  title: l10n.settingsSnoozeDuration,
                  value: settings.snoozeDuration,
                  options: AppSettings.snoozeOptions,
                  label: l10n.duration,
                  onChanged: (v) =>
                      update((s) => s.copyWith(snoozeDuration: v)),
                ),
              ],
            ),
            SectionHeader.compact(l10n.settingsSectionPermissions),
            const _Group(children: [AlertPermissionsTiles()]),
            SectionHeader.compact(l10n.settingsSectionAlerts),
            _Group(
              children: [
                _SwitchTile(
                  icon: Icons.fullscreen,
                  title: l10n.settingsFullScreen,
                  subtitle: l10n.settingsFullScreenSubtitle,
                  value: settings.fullScreenAlerts,
                  onChanged: (v) =>
                      update((s) => s.copyWith(fullScreenAlerts: v)),
                ),
                _SwitchTile(
                  icon: Icons.volume_up_outlined,
                  title: l10n.settingsSound,
                  value: settings.soundEnabled,
                  onChanged: (v) => update((s) => s.copyWith(soundEnabled: v)),
                ),
                _SwitchTile(
                  icon: Icons.vibration,
                  title: l10n.settingsVibration,
                  value: settings.vibrationEnabled,
                  onChanged: (v) =>
                      update((s) => s.copyWith(vibrationEnabled: v)),
                ),
                _SwitchTile(
                  icon: Icons.campaign_outlined,
                  title: l10n.settingsEscalation,
                  subtitle: l10n.settingsEscalationSubtitle,
                  value: settings.escalationEnabled,
                  onChanged: (v) =>
                      update((s) => s.copyWith(escalationEnabled: v)),
                ),
              ],
            ),
            SectionHeader.compact(l10n.settingsSectionQuietHours),
            _Group(
              children: [
                _SwitchTile(
                  icon: Icons.bedtime_outlined,
                  title: l10n.settingsQuietHours,
                  subtitle: l10n.settingsQuietHoursSubtitle,
                  value: settings.quietHoursEnabled,
                  onChanged: (v) =>
                      update((s) => s.copyWith(quietHoursEnabled: v)),
                ),
                if (settings.quietHoursEnabled) ...[
                  _TimeTile(
                    title: l10n.settingsFrom,
                    value: settings.quietHoursStart,
                    onChanged: (v) =>
                        update((s) => s.copyWith(quietHoursStart: v)),
                  ),
                  _TimeTile(
                    title: l10n.settingsTo,
                    value: settings.quietHoursEnd,
                    onChanged: (v) =>
                        update((s) => s.copyWith(quietHoursEnd: v)),
                  ),
                ],
              ],
            ),
            SectionHeader.compact(l10n.settingsSectionSummaries),
            _Group(
              children: [
                _SwitchTile(
                  icon: Icons.wb_sunny_outlined,
                  title: l10n.settingsMorningSummary,
                  subtitle: l10n.settingsMorningSummarySubtitle,
                  value: settings.morningSummaryEnabled,
                  onChanged: (v) =>
                      update((s) => s.copyWith(morningSummaryEnabled: v)),
                ),
                if (settings.morningSummaryEnabled)
                  _TimeTile(
                    title: l10n.fieldTime,
                    value: settings.morningSummaryTime,
                    onChanged: (v) =>
                        update((s) => s.copyWith(morningSummaryTime: v)),
                  ),
                _SwitchTile(
                  icon: Icons.nights_stay_outlined,
                  title: l10n.settingsNightSummary,
                  subtitle: l10n.settingsNightSummarySubtitle,
                  value: settings.nightSummaryEnabled,
                  onChanged: (v) =>
                      update((s) => s.copyWith(nightSummaryEnabled: v)),
                ),
                if (settings.nightSummaryEnabled)
                  _TimeTile(
                    title: l10n.fieldTime,
                    value: settings.nightSummaryTime,
                    onChanged: (v) =>
                        update((s) => s.copyWith(nightSummaryTime: v)),
                  ),
                const AddWidgetTile(),
              ],
            ),
            SectionHeader.compact(l10n.wakeSection),
            const _Group(children: [WakeWordSettingsTiles()]),
            SectionHeader.compact(l10n.settingsSectionAssistant),
            _Group(
              children: [
                _SwitchTile(
                  icon: Icons.record_voice_over_outlined,
                  title: l10n.settingsVoiceConfirmation,
                  subtitle: l10n.settingsVoiceConfirmationSubtitle,
                  value: settings.voiceConfirmation,
                  onChanged: (v) =>
                      update((s) => s.copyWith(voiceConfirmation: v)),
                ),
                const AssistantTiles(),
              ],
            ),
            SectionHeader.compact(l10n.settingsSectionPrivacy),
            _Group(
              children: [
                _SwitchTile(
                  icon: Icons.model_training,
                  title: l10n.settingsDataCollection,
                  subtitle: l10n.settingsDataCollectionSubtitle,
                  value: settings.dataCollectionConsent,
                  onChanged: (v) =>
                      update((s) => s.copyWith(dataCollectionConsent: v)),
                ),
                const _TrainingDataTile(),
                ListTile(
                  leading: const Icon(Icons.group_outlined),
                  title: Text(l10n.settingsSharing),
                  subtitle: Text(l10n.settingsSharingSubtitle),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => unawaited(context.push(AppRoutes.sharing)),
                ),
                ListTile(
                  leading: const Icon(Icons.place_outlined),
                  title: Text(l10n.settingsPlaces),
                  subtitle: Text(l10n.settingsPlacesSubtitle),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => unawaited(context.push(AppRoutes.places)),
                ),
                ListTile(
                  leading: const Icon(Icons.psychology_outlined),
                  title: Text(l10n.learningOpen),
                  subtitle: Text(l10n.learningOpenSubtitle),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => unawaited(context.push(AppRoutes.learning)),
                ),
              ],
            ),
            SectionHeader.compact(l10n.settingsSectionAppearance),
            _Group(
              children: [
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: SegmentedButton<AppThemeMode>(
                    segments: [
                      ButtonSegment(
                        value: AppThemeMode.system,
                        icon: const Icon(Icons.brightness_auto),
                        label: Text(l10n.themeSystem),
                      ),
                      ButtonSegment(
                        value: AppThemeMode.light,
                        icon: const Icon(Icons.light_mode_outlined),
                        label: Text(l10n.themeLight),
                      ),
                      ButtonSegment(
                        value: AppThemeMode.dark,
                        icon: const Icon(Icons.dark_mode_outlined),
                        label: Text(l10n.themeDark),
                      ),
                    ],
                    selected: {settings.themeMode},
                    onSelectionChanged: (selection) =>
                        update((s) => s.copyWith(themeMode: selection.first)),
                  ),
                ),
              ],
            ),
            SectionHeader.compact(l10n.settingsSectionAbout),
            _Group(
              children: [
                ListTile(
                  leading: const Icon(Icons.info_outline),
                  title: Text(l10n.settingsVersion),
                  trailing: Text(
                    switch (ref.watch(_packageInfoProvider)) {
                      AsyncData(:final value) =>
                        '${value.version} (${value.buildNumber})',
                      _ => '…',
                    },
                  ),
                ),
                if (ref.watch(flavorProvider).isDev)
                  ListTile(
                    leading: const Icon(Icons.developer_mode),
                    title: Text(l10n.settingsEnvironment),
                    trailing: const Text('DEV'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Frases guardadas para entrenar la IA, con opción de borrarlas.
class _TrainingDataTile extends ConsumerWidget {
  const _TrainingDataTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final count = ref.watch(trainingSampleCountProvider).value ?? 0;
    return ListTile(
      leading: const Icon(Icons.dataset_outlined),
      title: Text(l10n.settingsTrainingCount(count)),
      trailing: count == 0
          ? null
          : TextButton(
              onPressed: () => unawaited(_confirmDelete(context, ref)),
              child: Text(l10n.actionDelete),
            ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.settingsTrainingDelete),
        content: Text(l10n.settingsTrainingDeleteConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.actionCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.actionDelete),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref.read(trainingDataRepositoryProvider).clear();
    messenger.showSnackBar(
      SnackBar(content: Text(l10n.settingsTrainingDeleted)),
    );
  }
}

class _Group extends StatelessWidget {
  const _Group({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return GlassGroup(children: children);
  }
}

class _SwitchTile extends StatelessWidget {
  const _SwitchTile({
    required this.icon,
    required this.title,
    required this.value,
    required this.onChanged,
    this.subtitle,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      secondary: Icon(icon),
      title: Text(title),
      subtitle: subtitle == null ? null : Text(subtitle!),
      value: value,
      onChanged: onChanged,
    );
  }
}

class _DurationTile extends StatelessWidget {
  const _DurationTile({
    required this.icon,
    required this.title,
    required this.value,
    required this.options,
    required this.label,
    required this.onChanged,
  });

  final IconData icon;
  final String title;
  final Duration value;
  final List<Duration> options;
  final String Function(Duration) label;
  final ValueChanged<Duration> onChanged;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text(label(value)),
      trailing: const Icon(Icons.chevron_right),
      onTap: () async {
        final picked = await showDialog<Duration>(
          context: context,
          builder: (context) => SimpleDialog(
            title: Text(title),
            children: [
              RadioGroup<Duration>(
                groupValue: value,
                onChanged: (selected) => Navigator.of(context).pop(selected),
                child: Column(
                  children: [
                    for (final option in options)
                      RadioListTile<Duration>(
                        value: option,
                        title: Text(label(option)),
                      ),
                  ],
                ),
              ),
            ],
          ),
        );
        if (picked != null) onChanged(picked);
      },
    );
  }
}

class _TimeTile extends StatelessWidget {
  const _TimeTile({
    required this.title,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final DayTime value;
  final ValueChanged<DayTime> onChanged;

  @override
  Widget build(BuildContext context) {
    final asDate = DateTime(2000, 1, 1, value.hour, value.minute);
    return ListTile(
      leading: const SizedBox(width: 24),
      title: Text(title),
      trailing: Text(
        context.l10n.time(asDate),
        style: context.textTheme.titleSmall,
      ),
      onTap: () async {
        final picked = await showTimePicker(
          context: context,
          initialTime: TimeOfDay(hour: value.hour, minute: value.minute),
        );
        if (picked != null) onChanged(DayTime(picked.hour, picked.minute));
      },
    );
  }
}
