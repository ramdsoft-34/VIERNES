import 'dart:convert';

import 'package:home_widget/home_widget.dart';
import 'package:viernes/features/summaries/application/agenda_sync.dart';

/// Envía la agenda al widget nativo (`AgendaWidgetProvider.kt`).
///
/// Se guardan las fechas y no textos como "Hoy": el widget los calcula al
/// dibujarse, así no queda desactualizado al pasar la medianoche.
class HomeWidgetService implements HomeWidgetUpdater {
  const HomeWidgetService();

  static const _provider = 'com.ramdsoft.viernes.widget.AgendaWidgetProvider';

  @override
  Future<void> update(List<WidgetItem> items) async {
    await HomeWidget.saveWidgetData<String>(
      'agenda',
      jsonEncode([for (final item in items) item.toJson()]),
    );
    await HomeWidget.updateWidget(qualifiedAndroidName: _provider);
  }
}
