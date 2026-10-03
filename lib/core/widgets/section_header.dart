import 'package:flutter/material.dart';
import 'package:viernes/core/extensions/context_x.dart';

class SectionHeader extends StatelessWidget {
  const SectionHeader(this.title, {this.trailing, this.color, super.key})
    : compact = false;

  /// Título discreto para agrupar filas (ajustes).
  const SectionHeader.compact(
    this.title, {
    this.trailing,
    this.color,
    super.key,
  }) : compact = true;

  final String title;
  final bool compact;
  final Widget? trailing;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: compact
          ? const EdgeInsets.fromLTRB(16, 22, 0, 8)
          : const EdgeInsets.fromLTRB(4, 28, 0, 10),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: compact
                  ? context.textTheme.labelMedium?.copyWith(
                      color: color ?? context.colors.onSurfaceVariant,
                    )
                  : context.textTheme.titleLarge?.copyWith(
                      color: color ?? context.colors.onSurface,
                    ),
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}
