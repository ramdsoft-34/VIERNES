import 'dart:async';

import 'package:flutter/material.dart' hide DayPeriod;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:viernes/ai/ai_providers.dart';
import 'package:viernes/ai/dataset/training_exporter.dart';
import 'package:viernes/ai/learning/personal_model.dart';
import 'package:viernes/ai/nlu/interpretation.dart';
import 'package:viernes/ai/nlu/ml/neural_tagger.dart';
import 'package:viernes/ai/wake_word/wake_sample_store.dart';
import 'package:viernes/app/providers.dart';
import 'package:viernes/app/theme/app_theme.dart';
import 'package:viernes/core/extensions/context_x.dart';
import 'package:viernes/core/logging/app_logger.dart';
import 'package:viernes/core/utils/day_time.dart';
import 'package:viernes/core/widgets/section_header.dart';
import 'package:viernes/features/alerts/presentation/alert_providers.dart';
import 'package:viernes/features/reminders/presentation/reminder_formatters.dart';
import 'package:viernes/features/settings/presentation/settings_controller.dart';
import 'package:viernes/features/voice_assistant/presentation/wake_word_controller.dart';

/// "Cómo aprende Viernes": qué aprendió, qué tan bien entiende y control
/// sobre los datos.
class LearningScreen extends ConsumerWidget {
  const LearningScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final settings = ref.watch(settingsControllerProvider);
    final controller = ref.read(settingsControllerProvider.notifier);
    final model = ref.watch(personalModelProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.learningTitle)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
        children: [
          const SizedBox(height: 8),
          Card(
            color: context.colors.primaryContainer,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(
                    Icons.lock_outline,
                    color: context.colors.onPrimaryContainer,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      l10n.learningPrivacy,
                      style: TextStyle(
                        color: context.colors.onPrimaryContainer,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Card(
            child: SwitchListTile(
              secondary: const Icon(Icons.psychology_outlined),
              title: Text(l10n.learningEnable),
              subtitle: Text(l10n.learningEnableSubtitle),
              value: settings.personalLearning,
              onChanged: (value) => controller.update(
                (s) => s.copyWith(personalLearning: value),
              ),
            ),
          ),
          if (settings.personalLearning && model != null) ...[
            SectionHeader(l10n.learningWhatItLearned),
            _ModelCard(model: model),
          ],
          if (settings.personalLearning) const _SnoozeHabitCard(),
          SectionHeader(l10n.batterySection),
          const _BatteryCard(),
          SectionHeader(l10n.wakeSamplesSection),
          const _WakeSamplesCard(),
          SectionHeader(l10n.neuralSection),
          const _NeuralCard(),
          SectionHeader(l10n.learningConversations),
          const _ConversationsCard(),
        ],
      ),
    );
  }
}

class _ModelCard extends StatelessWidget {
  const _ModelCard({required this.model});

  final PersonalModel model;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final accuracy = model.categoryAccuracy;
    final habits = model.habits;
    final periods = {
      DayPeriod.morning: l10n.learningMorning,
      DayPeriod.afternoon: l10n.learningAfternoon,
      DayPeriod.night: l10n.learningNight,
    };
    return Card(
      child: Column(
        children: [
          ListTile(
            leading: const Icon(Icons.dataset_outlined),
            title: Text(l10n.learningTrainedOn(model.trainedOn)),
          ),
          const Divider(height: 1, indent: 56),
          ListTile(
            leading: const Icon(Icons.category_outlined),
            title: Text(l10n.learningCategories),
            subtitle: Text(
              accuracy == null
                  ? l10n.learningNeedsMoreData
                  : l10n.learningAccuracy((accuracy * 100).round()),
            ),
          ),
          const Divider(height: 1, indent: 56),
          ListTile(
            leading: const Icon(Icons.schedule),
            title: Text(l10n.learningYourTimes),
            subtitle: Text(
              [
                for (final MapEntry(key: period, value: label)
                    in periods.entries)
                  '$label: ${_time(context, habits.periodTimes[period])}',
              ].join('\n'),
            ),
          ),
          if (habits.leadTimes.isNotEmpty) ...[
            const Divider(height: 1, indent: 56),
            ListTile(
              leading: const Icon(Icons.notifications_active_outlined),
              title: Text(l10n.learningLeadTimes),
              subtitle: Text(
                [
                  for (final MapEntry(key: category, value: lead)
                      in habits.leadTimes.entries)
                    '${l10n.category(category)}: ${l10n.leadTime(lead)}',
                ].join('\n'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _time(BuildContext context, DayTime? learned) {
    final l10n = context.l10n;
    if (learned == null) return l10n.learningNotYet;
    return l10n.time(DateTime(2000, 1, 1, learned.hour, learned.minute));
  }
}

class _ConversationsCard extends ConsumerWidget {
  const _ConversationsCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final settings = ref.watch(settingsControllerProvider);
    final report = ref.watch(accuracyReportProvider).value;
    final rate = report?.firstTryRate;

    Future<void> export() async {
      final messenger = ScaffoldMessenger.of(context);
      try {
        await TrainingExporter(
          ref.read(trainingDataRepositoryProvider),
        ).exportAndShare(ref.read(clockProvider).now());
      } on Object catch (error) {
        AppLogger.error('No se pudo exportar', error: error);
        messenger.showSnackBar(SnackBar(content: Text(l10n.errorGeneric)));
      }
    }

    return Card(
      child: Column(
        children: [
          SwitchListTile(
            secondary: const Icon(Icons.model_training),
            title: Text(l10n.settingsDataCollection),
            subtitle: Text(l10n.settingsDataCollectionSubtitle),
            value: settings.dataCollectionConsent,
            onChanged: (value) => ref
                .read(settingsControllerProvider.notifier)
                .update((s) => s.copyWith(dataCollectionConsent: value)),
          ),
          if (report != null && report.total > 0) ...[
            const Divider(height: 1, indent: 56),
            ListTile(
              leading: const Icon(
                Icons.check_circle_outline,
                color: AppTheme.seed,
              ),
              title: Text(l10n.settingsTrainingCount(report.total)),
              subtitle: Text(
                [
                  if (rate != null) l10n.learningFirstTry((rate * 100).round()),
                  l10n.learningTitleFixes(report.titleCorrections),
                ].join('\n'),
              ),
            ),
            const Divider(height: 1, indent: 56),
            ListTile(
              leading: const Icon(Icons.ios_share),
              title: Text(l10n.learningExport),
              subtitle: Text(l10n.learningExportSubtitle),
              onTap: () => unawaited(export()),
            ),
          ],
        ],
      ),
    );
  }
}

/// Red neuronal propia: qué tan bien entiende, modo experimental y un campo
/// para probarla.
class _NeuralCard extends ConsumerStatefulWidget {
  const _NeuralCard();

  @override
  ConsumerState<_NeuralCard> createState() => _NeuralCardState();
}

class _NeuralCardState extends ConsumerState<_NeuralCard> {
  final _text = TextEditingController();
  TaggerResult? _result;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final tagger = ref.watch(neuralTaggerProvider).value;
    final settings = ref.watch(settingsControllerProvider);
    if (tagger == null) {
      return Card(child: ListTile(title: Text(l10n.neuralUnavailable)));
    }
    final unseen = tagger.metrics['unseen_tasks'];
    final accuracy = unseen is Map
        ? ((unseen['title_exact'] as num? ?? 0) * 100).round()
        : null;
    final result = _result;
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ListTile(
              leading: const Icon(Icons.hub_outlined),
              title: Text(l10n.neuralVersion(tagger.version)),
              subtitle: accuracy == null
                  ? null
                  : Text(l10n.neuralAccuracy(accuracy)),
            ),
            if (ref.watch(neuralComparisonProvider).value case final c?)
              ListTile(
                leading: const Icon(Icons.compare_arrows),
                title: Text(
                  c.meaningful
                      ? l10n.neuralCompare(
                          c.samples,
                          (c.rulesAccuracy * 100).round(),
                          (c.neuralAccuracy * 100).round(),
                        )
                      : l10n.neuralCompareNeedsData,
                ),
              ),
            SwitchListTile(
              secondary: const Icon(Icons.science_outlined),
              title: Text(l10n.neuralTitles),
              subtitle: Text(l10n.neuralTitlesSubtitle),
              value: settings.neuralTitles,
              onChanged: (value) => ref
                  .read(settingsControllerProvider.notifier)
                  .update((s) => s.copyWith(neuralTitles: value)),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: TextField(
                controller: _text,
                decoration: InputDecoration(
                  labelText: l10n.neuralTry,
                  hintText: l10n.neuralTryHint,
                  border: const OutlineInputBorder(),
                ),
                onChanged: (value) => setState(
                  () =>
                      _result = value.trim().isEmpty ? null : tagger.tag(value),
                ),
              ),
            ),
            if (result != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    Chip(
                      label: Text(
                        '${result.intent} · '
                        '${(result.intentConfidence * 100).round()} %',
                      ),
                    ),
                    for (final span in result.spans)
                      Chip(
                        avatar: Text(span.label.substring(0, 1)),
                        label: Text('${span.label}: ${span.text}'),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Grabaciones de cada «Viernes» para reentrenar el detector.
/// Lo aprendido sobre cuánto suele posponer.
class _SnoozeHabitCard extends ConsumerWidget {
  const _SnoozeHabitCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final habits = ref.watch(snoozeHabitsProvider);
    final learned = habits.learned();
    if (learned == null) return const SizedBox.shrink();
    return Card(
      child: ListTile(
        leading: const Icon(Icons.snooze),
        title: Text(l10n.learningSnooze(l10n.duration(learned))),
        subtitle: Text(l10n.learningSnoozeSubtitle),
        trailing: TextButton(
          onPressed: () async {
            await habits.clear();
            ref.invalidate(snoozeHabitsProvider);
          },
          child: Text(l10n.learningForget),
        ),
      ),
    );
  }
}

/// Cuánto gasta escuchar «Viernes» en este teléfono.
class _BatteryCard extends ConsumerWidget {
  const _BatteryCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final stats = ref.watch(wakeStatsProvider).value;
    if (stats == null || stats.listening < const Duration(minutes: 1)) {
      return Card(
        child: ListTile(
          leading: const Icon(Icons.battery_std),
          title: Text(l10n.batteryNoData),
          subtitle: Text(l10n.batteryNoDataSubtitle),
        ),
      );
    }
    final hours = stats.listening.inMinutes / 60;
    final perHour = stats.batteryPercentPerHour;
    return Card(
      child: Column(
        children: [
          ListTile(
            leading: const Icon(Icons.battery_charging_full),
            title: Text(
              perHour == null
                  ? l10n.batteryMeasuring
                  : l10n.batteryPerHour(perHour.toStringAsFixed(1)),
            ),
            subtitle: Text(
              l10n.batteryListening(
                hours.toStringAsFixed(1),
                (stats.savedRatio * 100).round(),
              ),
            ),
          ),
          ListTile(
            dense: true,
            leading: const Icon(Icons.memory),
            title: Text(
              l10n.batteryCpu(
                stats.cpuPercent?.toStringAsFixed(1) ?? '–',
                stats.averageInferenceMs.toStringAsFixed(1),
              ),
            ),
          ),
          OverflowBar(
            alignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () async {
                  await ref.read(wakeWordServiceProvider).resetStats();
                  ref.invalidate(wakeStatsProvider);
                },
                child: Text(l10n.batteryReset),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _WakeSamplesCard extends ConsumerWidget {
  const _WakeSamplesCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final counts =
        ref.watch(wakeSampleCountsProvider).value ?? const WakeSampleCounts();
    final store = ref.read(wakeSampleStoreProvider);
    return Card(
      child: Column(
        children: [
          ListTile(
            leading: const Icon(Icons.graphic_eq),
            title: Text(l10n.wakeSamplesTitle(counts.real, counts.errors)),
            subtitle: Text(l10n.wakeSamplesSubtitle),
          ),
          if (counts.total > 0)
            OverflowBar(
              alignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () async {
                    await store.clear();
                    ref.invalidate(wakeSampleCountsProvider);
                  },
                  child: Text(l10n.wakeSamplesDelete),
                ),
                TextButton(
                  onPressed: () => unawaited(store.exportAndShare()),
                  child: Text(l10n.wakeSamplesExport),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
