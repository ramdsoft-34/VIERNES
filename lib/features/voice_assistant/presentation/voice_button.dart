import 'dart:async';

import 'package:flutter/material.dart';
import 'package:viernes/core/extensions/context_x.dart';
import 'package:viernes/features/voice_assistant/presentation/voice_assistant_sheet.dart';

/// Botón principal para hablar con Viernes.
class VoiceButton extends StatelessWidget {
  const VoiceButton({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final l10n = context.l10n;
    return Semantics(
      button: true,
      label: l10n.voiceButtonLabel,
      child: Card(
        color: colors.primary,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => unawaited(showVoiceAssistant(context)),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: colors.onPrimary.withValues(alpha: 0.18),
                    shape: BoxShape.circle,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Icon(Icons.mic, size: 32, color: colors.onPrimary),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.voiceButtonLabel,
                        style: context.textTheme.titleMedium?.copyWith(
                          color: colors.onPrimary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        l10n.voiceButtonHint,
                        style: context.textTheme.bodyMedium?.copyWith(
                          color: colors.onPrimary.withValues(alpha: 0.85),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
