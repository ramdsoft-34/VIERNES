import 'dart:async';

import 'package:flutter/material.dart';
import 'package:home_widget/home_widget.dart';
import 'package:viernes/core/extensions/context_x.dart';
import 'package:viernes/core/logging/app_logger.dart';

/// Pide a Android que agregue el widget de Viernes a la pantalla de inicio.
class AddWidgetTile extends StatelessWidget {
  const AddWidgetTile({super.key});

  static const _provider = 'com.ramdsoft.viernes.widget.AgendaWidgetProvider';

  Future<void> _request() async {
    try {
      if (await HomeWidget.isRequestPinWidgetSupported() ?? false) {
        await HomeWidget.requestPinWidget(qualifiedAndroidName: _provider);
      }
    } on Object catch (error) {
      AppLogger.error('No se pudo agregar el widget', error: error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return ListTile(
      leading: const Icon(Icons.widgets_outlined),
      title: Text(l10n.widgetAdd),
      subtitle: Text(l10n.widgetAddSubtitle),
      trailing: const Icon(Icons.add),
      onTap: () => unawaited(_request()),
    );
  }
}
