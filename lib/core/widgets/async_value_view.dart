import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:viernes/core/extensions/context_x.dart';
import 'package:viernes/core/logging/app_logger.dart';

/// Pinta un [AsyncValue] con estados de carga y error uniformes.
class AsyncValueView<T> extends StatelessWidget {
  const AsyncValueView({required this.value, required this.data, super.key});

  final AsyncValue<T> value;
  final Widget Function(T data) data;

  @override
  Widget build(BuildContext context) {
    return value.when(
      data: data,
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stackTrace) {
        AppLogger.error(
          'Error al cargar datos',
          error: error,
          stackTrace: stackTrace,
        );
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              context.l10n.errorGeneric,
              textAlign: TextAlign.center,
            ),
          ),
        );
      },
    );
  }
}
