import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:viernes/ai/wake_word/voice_profile_service.dart';
import 'package:viernes/app/theme/app_theme.dart';
import 'package:viernes/core/extensions/context_x.dart';
import 'package:viernes/core/widgets/liquid.dart';
import 'package:viernes/features/settings/presentation/settings_controller.dart';
import 'package:viernes/features/voice_assistant/presentation/wake_word_controller.dart';

enum _Step { intro, recording, saving, done, testing }

/// Registrar la voz del dueño: dice «Viernes» cinco veces. Después se puede
/// probar si la reconoce. La voz se guarda solo en este teléfono.
class VoiceEnrollmentScreen extends ConsumerStatefulWidget {
  const VoiceEnrollmentScreen({super.key});

  @override
  ConsumerState<VoiceEnrollmentScreen> createState() =>
      _VoiceEnrollmentScreenState();
}

class _VoiceEnrollmentScreenState extends ConsumerState<VoiceEnrollmentScreen> {
  static const int _needed = VoiceProfileService.samplesNeeded;

  _Step _step = _Step.intro;
  int _count = 0;
  bool _busy = false;
  String? _hint;
  bool? _testAccepted;
  double? _testSimilarity;
  late final WakeWordController _wake;

  VoiceProfileService get _voice => ref.read(voiceProfileServiceProvider);

  @override
  void initState() {
    super.initState();
    _wake = ref.read(wakeWordControllerProvider.notifier);
    // El micrófono es de esta pantalla mientras está abierta.
    unawaited(_wake.pause());
  }

  @override
  void dispose() {
    unawaited(_wake.voiceChanged());
    super.dispose();
  }

  Future<void> _start() async {
    await _voice.startEnrollment();
    if (!mounted) return;
    setState(() {
      _step = _Step.recording;
      _count = 0;
      _hint = null;
    });
  }

  Future<void> _record() async {
    if (_busy) return;
    final l10n = context.l10n;
    setState(() {
      _busy = true;
      _hint = l10n.voiceEnrollSayNow;
    });
    final sample = await _voice.recordSample();
    if (!mounted) return;
    setState(() {
      _busy = false;
      if (sample.ok) {
        _count = sample.count;
        _hint = _count >= _needed ? null : l10n.voiceEnrollGood;
      } else {
        _hint = _problem(sample.problem);
      }
    });
    if (_count >= _needed) await _save();
  }

  Future<void> _save() async {
    setState(() => _step = _Step.saving);
    final saved = await _voice.finishEnrollment();
    if (!mounted) return;
    setState(() {
      _step = saved ? _Step.done : _Step.recording;
      _hint = saved ? null : context.l10n.errorGeneric;
    });
  }

  Future<void> _test() async {
    if (_busy) return;
    setState(() {
      _step = _Step.testing;
      _busy = true;
      _testAccepted = null;
      _hint = context.l10n.voiceEnrollSayNow;
    });
    final sample = await _voice.testSample();
    if (!mounted) return;
    setState(() {
      _busy = false;
      if (sample.ok) {
        _testAccepted = sample.accepted;
        _testSimilarity = sample.similarity;
        _hint = null;
      } else {
        _hint = _problem(sample.problem);
      }
    });
  }

  String _problem(SampleProblem problem) {
    final l10n = context.l10n;
    return switch (problem) {
      SampleProblem.quiet => l10n.voiceEnrollQuiet,
      SampleProblem.short => l10n.voiceEnrollShort,
      SampleProblem.permission => l10n.wakeErrorMic,
      _ => l10n.errorGeneric,
    };
  }

  Future<void> _activate() async {
    await ref.read(wakeWordControllerProvider.notifier).enable();
    if (mounted) unawaited(Navigator.of(context).maybePop());
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final status = ref.watch(voiceProfileStatusProvider).value;
    final enrolled = status?.enrolled ?? false;
    final wakeOn = ref.watch(
      settingsControllerProvider.select((s) => s.wakeWordEnabled),
    );
    final text = context.textTheme;
    final p = LiquidPalette.of(context);

    final (title, body) = switch (_step) {
      _Step.intro when enrolled => (
        l10n.voiceEnrollRegistered,
        l10n.voiceEnrollRegisteredBody,
      ),
      _Step.intro => (l10n.voiceEnrollTitle, l10n.voiceEnrollIntro),
      _Step.recording => (
        l10n.voiceEnrollProgress(_count, _needed),
        l10n.voiceEnrollInstruction,
      ),
      _Step.saving => (l10n.voiceEnrollSaving, ''),
      _Step.done => (l10n.voiceEnrollDone, l10n.voiceEnrollDoneBody),
      _Step.testing => (
        switch (_testAccepted) {
          true => l10n.voiceTestYes,
          false => l10n.voiceTestNo,
          null => l10n.voiceTestTitle,
        },
        switch (_testAccepted) {
          true => l10n.voiceTestYesBody(
            ((_testSimilarity ?? 0) * 100).round(),
          ),
          false => l10n.voiceTestNoBody,
          null => l10n.voiceEnrollInstruction,
        },
      ),
    };

    final orbTap = switch (_step) {
      _Step.recording => _record,
      _Step.testing || _Step.done => _test,
      _ => null,
    };

    return LiquidScaffold(
      appBar: AppBar(title: Text(l10n.voiceEnrollAppBar)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
          children: [
            Text(title, style: text.headlineMedium),
            if (body.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(body, style: text.bodyLarge),
            ],
            const SizedBox(height: 32),
            Center(
              child: Semantics(
                button: orbTap != null,
                label: l10n.voiceEnrollTapToRecord,
                child: GestureDetector(
                  onTap: orbTap == null || _busy
                      ? null
                      : () => unawaited(orbTap()),
                  child: VoiceOrb(
                    size: 168,
                    listening: _busy,
                    thinking: _step == _Step.saving,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            if (_step == _Step.recording) _Dots(count: _count, total: _needed),
            if (_hint != null) ...[
              const SizedBox(height: 14),
              Text(
                _hint!,
                textAlign: TextAlign.center,
                style: text.titleMedium?.copyWith(color: p.accentText),
              ),
            ],
            if (orbTap != null && !_busy && _hint == null) ...[
              const SizedBox(height: 14),
              Text(
                l10n.voiceEnrollTapToRecord,
                textAlign: TextAlign.center,
                style: text.bodyMedium,
              ),
            ],
            const SizedBox(height: 32),
            ..._actions(enrolled: enrolled, wakeOn: wakeOn),
            const SizedBox(height: 24),
            LiquidGlass(
              blur: false,
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.lock_outline_rounded, color: p.textSecondary),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(l10n.voiceEnrollPrivacy, style: text.bodySmall),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _actions({required bool enrolled, required bool wakeOn}) {
    final l10n = context.l10n;
    switch (_step) {
      case _Step.intro:
        return [
          FilledButton.icon(
            onPressed: () => unawaited(_start()),
            icon: const Icon(Icons.mic_rounded),
            label: Text(
              enrolled ? l10n.voiceEnrollAgain : l10n.voiceEnrollStart,
            ),
          ),
          if (enrolled) ...[
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: () => unawaited(_test()),
              icon: const Icon(Icons.hearing_rounded),
              label: Text(l10n.voiceTestTitle),
            ),
          ],
        ];
      case _Step.recording || _Step.saving:
        return const [];
      case _Step.done || _Step.testing:
        return [
          if (!wakeOn)
            FilledButton.icon(
              onPressed: () => unawaited(_activate()),
              icon: const Icon(Icons.record_voice_over_rounded),
              label: Text(l10n.voiceEnrollActivate),
            )
          else
            FilledButton(
              onPressed: () => Navigator.of(context).maybePop(),
              child: Text(l10n.voiceEnrollFinish),
            ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: _busy ? null : () => unawaited(_test()),
            icon: const Icon(Icons.hearing_rounded),
            label: Text(l10n.voiceTestTitle),
          ),
          if (_testAccepted == false) ...[
            const SizedBox(height: 10),
            TextButton(
              onPressed: () => unawaited(_start()),
              child: Text(l10n.voiceEnrollAgain),
            ),
          ],
        ];
    }
  }
}

class _Dots extends StatelessWidget {
  const _Dots({required this.count, required this.total});

  final int count;
  final int total;

  @override
  Widget build(BuildContext context) {
    final p = LiquidPalette.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < total; i++)
          AnimatedContainer(
            duration: LiquidMotion.of(context, LiquidMotion.fast),
            margin: const EdgeInsets.symmetric(horizontal: 5),
            width: i < count ? 22 : 10,
            height: 10,
            decoration: BoxDecoration(
              color: i < count ? p.accent : p.hairline,
              borderRadius: BorderRadius.circular(LiquidRadius.pill),
            ),
          ),
      ],
    );
  }
}
