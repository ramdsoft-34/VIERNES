import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:viernes/app/theme/liquid_palette.dart';
import 'package:viernes/core/extensions/context_x.dart';
import 'package:viernes/core/widgets/liquid.dart';
import 'package:viernes/features/voice_assistant/presentation/voice_assistant_sheet.dart';

/// Estructura principal: el fondo de luz, las pestañas y el dock flotante de
/// vidrio con el orbe para hablar.
class AppShell extends StatelessWidget {
  const AppShell({required this.shell, super.key});

  final StatefulNavigationShell shell;

  /// Espacio que ocupa el dock (las listas lo dejan libre al final).
  static const dockClearance = 96.0;

  /// Índice de la rama de Ajustes (se abre desde el engranaje, no del dock).
  static const settingsBranch = 4;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final media = MediaQuery.of(context);
    final items = [
      DockItem(Icons.radio_button_checked, l10n.navHome),
      DockItem(Icons.checklist_rounded, l10n.navReminders),
      DockItem(Icons.calendar_today_rounded, l10n.navCalendar),
      DockItem(Icons.insights_rounded, l10n.navHistory),
    ];
    return AmbientBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Stack(
          children: [
            // El contenido pasa por debajo del dock (se ve a través del
            // vidrio) y deja espacio al final para no quedar tapado.
            MediaQuery(
              data: media.copyWith(
                padding: media.padding.copyWith(
                  bottom: media.padding.bottom + dockClearance,
                ),
              ),
              child: shell,
            ),
            Positioned(
              left: 16,
              right: 16,
              bottom: media.padding.bottom + 16,
              child: Row(
                children: [
                  Expanded(
                    child: LiquidDock(
                      items: items,
                      current: shell.currentIndex < items.length
                          ? shell.currentIndex
                          : null,
                      onSelected: (index) => shell.goBranch(
                        index,
                        // Tocar la pestaña activa vuelve a su inicio.
                        initialLocation: index == shell.currentIndex,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  _OrbButton(label: l10n.voiceButtonLabel),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class DockItem {
  const DockItem(this.icon, this.label);

  final IconData icon;
  final String label;
}

/// Dock de vidrio: la pestaña activa se ensancha y muestra su nombre con
/// un resorte.
class LiquidDock extends StatelessWidget {
  const LiquidDock({
    required this.items,
    required this.current,
    required this.onSelected,
    super.key,
  });

  final List<DockItem> items;
  final int? current;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final p = LiquidPalette.of(context);
    final text = Theme.of(context).textTheme;
    final duration = LiquidMotion.of(context, LiquidMotion.medium);
    return LiquidGlass(
      radius: 32,
      child: SizedBox(
        height: 64,
        child: LayoutBuilder(
          builder: (context, constraints) {
            // Si no cabe el nombre, solo íconos (el nombre queda en la
            // pista y en el lector de pantalla).
            final showLabel = constraints.maxWidth >= 270;
            return Padding(
              padding: const EdgeInsets.all(6),
              child: Row(
                children: [
                  for (final (index, item) in items.indexed)
                    _tab(p, text, duration, index, item, showLabel),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _tab(
    LiquidPalette p,
    TextTheme text,
    Duration duration,
    int index,
    DockItem item,
    bool showLabel,
  ) {
    final active = index == current;
    final child = Tooltip(
      message: item.label,
      child: PressScale(
        onTap: () => onSelected(index),
        semanticLabel: item.label,
        scale: 0.9,
        child: AnimatedContainer(
          duration: duration,
          curve: LiquidMotion.spring,
          height: 52,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: active ? p.text.withValues(alpha: 0.13) : Colors.transparent,
            borderRadius: BorderRadius.circular(26),
            border: Border.all(
              color: active ? p.glassBorder : Colors.transparent,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                item.icon,
                size: 22,
                color: active ? p.text : p.textSecondary,
              ),
              AnimatedSize(
                duration: duration,
                curve: LiquidMotion.settle,
                child: active && showLabel
                    ? Padding(
                        padding: const EdgeInsets.only(left: 8),
                        child: Text(
                          item.label,
                          maxLines: 1,
                          style: text.labelMedium,
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
            ],
          ),
        ),
      ),
    );
    return active && showLabel ? child : Expanded(child: child);
  }
}

class _OrbButton extends StatelessWidget {
  const _OrbButton({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final p = LiquidPalette.of(context);
    return Tooltip(
      message: label,
      child: PressScale(
        onTap: () => unawaited(showVoiceAssistant(context)),
        semanticLabel: label,
        scale: 0.88,
        haptic: true,
        child: SizedBox.square(
          dimension: 64,
          child: LiquidGlass(
            shape: BoxShape.circle,
            child: Center(
              child: Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: p.accent,
                  boxShadow: [
                    BoxShadow(
                      color: p.accent.withValues(alpha: 0.22),
                      spreadRadius: 6,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
