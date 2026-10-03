import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:viernes/ai/wake_word/voice_profile_service.dart';
import 'package:viernes/app/router/routes.dart';
import 'package:viernes/core/extensions/context_x.dart';
import 'package:viernes/features/settings/domain/app_settings.dart';
import 'package:viernes/features/settings/presentation/settings_controller.dart';
import 'package:viernes/features/voice_assistant/presentation/wake_word_controller.dart';

/// Ajustes de "Decir «Viernes» para activar".
class WakeWordSettingsTiles extends ConsumerWidget {
  const WakeWordSettingsTiles({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final state = ref.watch(wakeWordControllerProvider);
    final controller = ref.read(wakeWordControllerProvider.notifier);
    final settings = ref.watch(settingsControllerProvider);
    final enabled = settings.wakeWordEnabled;
    final voice = ref.watch(voiceProfileStatusProvider).value;
    final hasVoice = voice?.enrolled ?? false;

    final subtitle = switch (state.phase) {
      WakeWordPhase.downloading => l10n.wakeDownloading(
        (state.progress * 100).round(),
      ),
      WakeWordPhase.preparing => l10n.voiceStarting,
      WakeWordPhase.listening => l10n.wakeListening,
      WakeWordPhase.error => state.error ?? l10n.errorGeneric,
      WakeWordPhase.off when !hasVoice => l10n.wakeNeedsVoice,
      WakeWordPhase.off =>
        state.modelInstalled || settings.wakeEngine == WakeEngine.own
            ? l10n.wakeSubtitle
            : l10n.wakeDownloadNote,
    };

    void openEnrollment() => unawaited(context.push(AppRoutes.voiceEnrollment));

    return Column(
      children: [
        ListTile(
          leading: Icon(
            hasVoice ? Icons.how_to_reg_rounded : Icons.mic_none_rounded,
          ),
          title: Text(l10n.voiceProfileTile),
          subtitle: Text(
            hasVoice
                ? l10n.voiceProfileRegistered(voice!.accepted, voice.rejected)
                : l10n.voiceProfileMissing,
          ),
          trailing: hasVoice
              ? const Icon(Icons.chevron_right_rounded)
              : FilledButton(
                  onPressed: openEnrollment,
                  child: Text(l10n.voiceProfileRegister),
                ),
          onTap: openEnrollment,
        ),
        if (hasVoice) ...[
          ListTile(
            leading: const Icon(Icons.verified_user_outlined),
            title: Text(l10n.voiceStrictness),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SegmentedButton<VoiceStrictness>(
                    showSelectedIcon: false,
                    segments: [
                      ButtonSegment(
                        value: VoiceStrictness.relaxed,
                        label: Text(l10n.voiceStrictnessRelaxed),
                      ),
                      ButtonSegment(
                        value: VoiceStrictness.normal,
                        label: Text(l10n.voiceStrictnessNormal),
                      ),
                      ButtonSegment(
                        value: VoiceStrictness.strict,
                        label: Text(l10n.voiceStrictnessStrict),
                      ),
                    ],
                    selected: {voice!.strictness},
                    onSelectionChanged: (selection) async {
                      await ref
                          .read(voiceProfileServiceProvider)
                          .setStrictness(selection.first);
                      ref.invalidate(voiceProfileStatusProvider);
                    },
                  ),
                  const SizedBox(height: 6),
                  Text(switch (voice.strictness) {
                    VoiceStrictness.relaxed => l10n.voiceStrictnessRelaxedNote,
                    VoiceStrictness.normal => l10n.voiceStrictnessNormalNote,
                    VoiceStrictness.strict => l10n.voiceStrictnessStrictNote,
                  }),
                ],
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.delete_outline_rounded),
            title: Text(l10n.voiceProfileDelete),
            subtitle: Text(l10n.voiceProfileDeleteNote),
            onTap: () async {
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: Text(l10n.voiceProfileDelete),
                  content: Text(l10n.voiceProfileDeleteNote),
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
              if (confirmed ?? false) await controller.deleteVoice();
            },
          ),
        ],
        const Divider(height: 1, indent: 56),
        SwitchListTile(
          secondary: const Icon(Icons.record_voice_over),
          title: Text(l10n.wakeEnable),
          subtitle: Text(subtitle),
          value: enabled || state.isBusy,
          onChanged: state.isBusy
              ? null
              : (value) {
                  if (value && !hasVoice) {
                    openEnrollment();
                    return;
                  }
                  unawaited(value ? controller.enable() : controller.disable());
                },
        ),
        if (state.phase == WakeWordPhase.downloading)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: LinearProgressIndicator(value: state.progress),
          ),
        if (enabled) ...[
          const Divider(height: 1, indent: 56),
          ListTile(
            leading: const Icon(Icons.tune),
            title: Text(l10n.wakeSensitivity),
            subtitle: Slider(
              value: settings.wakeSensitivity,
              divisions: 4,
              label: settings.wakeSensitivity < 0.34
                  ? l10n.wakeSensitivityLow
                  : settings.wakeSensitivity > 0.66
                  ? l10n.wakeSensitivityHigh
                  : l10n.wakeSensitivityMedium,
              onChanged: (value) => unawaited(controller.setSensitivity(value)),
            ),
          ),
          const Divider(height: 1, indent: 56),
          SwitchListTile(
            secondary: const Icon(Icons.notifications_active_outlined),
            title: Text(l10n.wakeChime),
            subtitle: Text(l10n.wakeChimeSubtitle),
            value: settings.wakeChime,
            onChanged: (value) => ref
                .read(settingsControllerProvider.notifier)
                .update((s) => s.copyWith(wakeChime: value)),
          ),
          const Divider(height: 1, indent: 56),
          SwitchListTile(
            secondary: const Icon(Icons.battery_saver_outlined),
            title: Text(l10n.wakeLowBattery),
            subtitle: Text(l10n.wakeLowBatterySubtitle),
            value: settings.lowBatteryPause,
            onChanged: (value) => ref
                .read(settingsControllerProvider.notifier)
                .update((s) => s.copyWith(lowBatteryPause: value)),
          ),
          const Divider(height: 1, indent: 56),
          ListTile(
            leading: const Icon(Icons.open_in_new),
            title: Text(l10n.wakeOverlay),
            subtitle: Text(l10n.wakeOverlaySubtitle),
            trailing: state.canOpenOverOtherApps
                ? Icon(
                    Icons.check_circle,
                    color: context.colors.onPrimaryContainer,
                  )
                : TextButton(
                    onPressed: () =>
                        unawaited(controller.requestOpenOverOtherApps()),
                    child: Text(l10n.permissionsGrant),
                  ),
          ),
        ],
        const Divider(height: 1, indent: 56),
        ListTile(
          leading: const Icon(Icons.memory),
          title: Text(l10n.wakeEngine),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SegmentedButton<WakeEngine>(
                  segments: [
                    ButtonSegment(
                      value: WakeEngine.own,
                      label: Text(l10n.wakeEngineOwn),
                    ),
                    ButtonSegment(
                      value: WakeEngine.vosk,
                      label: Text(l10n.wakeEngineVosk),
                    ),
                  ],
                  selected: {settings.wakeEngine},
                  onSelectionChanged: state.isBusy
                      ? null
                      : (selection) =>
                            unawaited(controller.setEngine(selection.first)),
                ),
                const SizedBox(height: 6),
                Text(
                  settings.wakeEngine == WakeEngine.own
                      ? l10n.wakeEngineOwnNote
                      : l10n.wakeEngineVoskNote,
                ),
              ],
            ),
          ),
        ),
        if (state.modelInstalled &&
            !state.ownModel &&
            !enabled &&
            !state.isBusy) ...[
          const Divider(height: 1, indent: 56),
          ListTile(
            leading: const Icon(Icons.delete_outline),
            title: Text(l10n.wakeRemoveModel),
            onTap: () => unawaited(controller.removeModel()),
          ),
        ],
      ],
    );
  }
}
