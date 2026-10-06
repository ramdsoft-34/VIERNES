import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import 'package:viernes/ai/ai_providers.dart';
import 'package:viernes/ai/nlu/es/spanish_text.dart';
import 'package:viernes/ai/speech/recorded_voice.dart';
import 'package:viernes/ai/speech/tts_speaker.dart';
import 'package:viernes/app/theme/app_theme.dart';
import 'package:viernes/core/extensions/context_x.dart';
import 'package:viernes/core/widgets/empty_state.dart';
import 'package:viernes/core/widgets/liquid.dart';
import 'package:viernes/features/settings/presentation/settings_controller.dart';

/// Prueba de la voz grabada: escuchar cada frase, compararla con la voz del
/// teléfono y decidir si Viernes la usa.
class RecordedVoiceScreen extends ConsumerStatefulWidget {
  const RecordedVoiceScreen({super.key});

  @override
  ConsumerState<RecordedVoiceScreen> createState() =>
      _RecordedVoiceScreenState();
}

class _RecordedVoiceScreenState extends ConsumerState<RecordedVoiceScreen> {
  final _player = AudioPlayer();
  final _tts = TtsSpeaker();
  final _search = TextEditingController();
  int? _playing;
  bool _playingAll = false;

  @override
  void dispose() {
    _playingAll = false;
    unawaited(_player.dispose());
    unawaited(_tts.stop());
    _search.dispose();
    super.dispose();
  }

  Future<void> _play(RecordedPhrase phrase) async {
    setState(() => _playing = phrase.id);
    try {
      await _player.stop();
      await _player.setAsset(phrase.asset);
      await _player.play();
      await _player.processingStateStream.firstWhere(
        (s) => s == ProcessingState.completed || s == ProcessingState.idle,
      );
    } on Object {
      // Si una frase no se puede reproducir, se sigue con la siguiente.
    }
    if (mounted && _playing == phrase.id && !_playingAll) {
      setState(() => _playing = null);
    }
  }

  Future<void> _playAll(List<RecordedPhrase> phrases) async {
    setState(() => _playingAll = true);
    for (final phrase in phrases) {
      if (!mounted || !_playingAll) break;
      await _play(phrase);
      await Future<void>.delayed(const Duration(milliseconds: 350));
    }
    if (mounted) {
      setState(() {
        _playingAll = false;
        _playing = null;
      });
    }
  }

  Future<void> _stop() async {
    setState(() {
      _playingAll = false;
      _playing = null;
    });
    await _player.stop();
    await _tts.stop();
  }

  Future<void> _compare(RecordedPhrase phrase) async {
    await _play(phrase);
    await Future<void>.delayed(const Duration(milliseconds: 500));
    if (!mounted) return;
    await _tts.speak(phrase.text);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final voice = ref.watch(recordedVoiceProvider);
    final enabled = ref.watch(
      settingsControllerProvider.select((s) => s.recordedVoice),
    );
    return LiquidScaffold(
      appBar: AppBar(
        title: Text(l10n.recordedVoiceTitle),
        actions: [
          if (_playing != null || _playingAll)
            IconButton(
              tooltip: l10n.recordedVoiceStop,
              onPressed: () => unawaited(_stop()),
              icon: const Icon(Icons.stop_rounded),
            ),
        ],
      ),
      body: switch (voice) {
        AsyncData(:final value) when value.isEmpty => EmptyState(
          icon: Icons.graphic_eq_rounded,
          title: l10n.recordedVoiceEmpty,
        ),
        AsyncData(:final value) => _list(value, enabled: enabled),
        _ => const Center(child: CircularProgressIndicator()),
      },
    );
  }

  static String _seconds(Duration d) =>
      (d.inMilliseconds / 1000).toStringAsFixed(1);

  Widget _list(RecordedVoice voice, {required bool enabled}) {
    final l10n = context.l10n;
    final p = LiquidPalette.of(context);
    final query = SpanishText.fold(_search.text.trim());
    final phrases = [
      for (final phrase in voice.phrases)
        if (query.isEmpty ||
            SpanishText.fold(phrase.text).contains(query) ||
            '${phrase.id}' == query)
          phrase,
    ];
    final seconds = voice.phrases.fold<int>(
      0,
      (sum, ph) => sum + ph.duration.inMilliseconds,
    );
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: [
        GlassGroup(
          children: [
            SwitchListTile(
              secondary: const Icon(Icons.record_voice_over_rounded),
              title: Text(l10n.recordedVoiceUse),
              subtitle: Text(l10n.recordedVoiceUseNote),
              value: enabled,
              onChanged: (value) => ref
                  .read(settingsControllerProvider.notifier)
                  .update((s) => s.copyWith(recordedVoice: value)),
            ),
            ListTile(
              leading: const Icon(Icons.library_music_outlined),
              title: Text(
                l10n.recordedVoiceCount(
                  voice.phrases.length,
                  (seconds / 60000).toStringAsFixed(1),
                ),
              ),
              trailing: FilledButton.icon(
                onPressed: _playingAll
                    ? null
                    : () => unawaited(_playAll(phrases)),
                icon: const Icon(Icons.play_arrow_rounded),
                label: Text(l10n.recordedVoicePlayAll),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _search,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            prefixIcon: const Icon(Icons.search_rounded),
            hintText: l10n.recordedVoiceSearch,
          ),
        ),
        const SizedBox(height: 12),
        for (final phrase in phrases)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: PressScale(
              onTap: () => unawaited(_play(phrase)),
              semanticLabel: phrase.text,
              child: LiquidGlass(
                blur: false,
                tint: _playing == phrase.id
                    ? p.accent.withValues(alpha: 0.18)
                    : null,
                padding: const EdgeInsets.fromLTRB(14, 10, 6, 10),
                child: Row(
                  children: [
                    SizedBox(
                      width: 40,
                      child: Text(
                        '${phrase.id}',
                        style: AppTheme.monoStyle(
                          context.textTheme.labelMedium,
                        ).copyWith(color: p.textMuted),
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(phrase.text, style: context.textTheme.bodyLarge),
                          Text(
                            '${_seconds(phrase.duration)} s · ${phrase.take}',
                            style: AppTheme.monoStyle(
                              context.textTheme.labelSmall,
                            ).copyWith(color: p.textMuted),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      _playing == phrase.id
                          ? Icons.graphic_eq_rounded
                          : Icons.play_arrow_rounded,
                      color: p.accentText,
                    ),
                    IconButton(
                      tooltip: l10n.recordedVoiceCompare,
                      onPressed: () => unawaited(_compare(phrase)),
                      icon: const Icon(Icons.compare_arrows_rounded),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}
