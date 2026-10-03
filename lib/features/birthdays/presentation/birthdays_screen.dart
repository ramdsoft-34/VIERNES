import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:viernes/app/providers.dart';
import 'package:viernes/core/extensions/context_x.dart';
import 'package:viernes/core/logging/app_logger.dart';
import 'package:viernes/core/platform/device_data.dart';
import 'package:viernes/core/widgets/empty_state.dart';
import 'package:viernes/features/birthdays/application/birthday_importer.dart';
import 'package:viernes/features/device/device_providers.dart';
import 'package:viernes/features/reminders/presentation/providers/reminder_providers.dart';
import 'package:viernes/features/reminders/presentation/reminder_formatters.dart';
import 'package:viernes/features/settings/domain/app_settings.dart';
import 'package:viernes/features/settings/presentation/settings_controller.dart';

final birthdayImporterProvider = Provider<BirthdayImporter>(
  (ref) => BirthdayImporter(
    prefs: ref.watch(sharedPreferencesProvider),
    create: ref.watch(createReminderProvider).call,
    now: ref.watch(clockProvider).now,
  ),
);

/// Permiso de contactos y cumpleaños encontrados.
typedef BirthdaysState = ({bool permission, List<ContactBirthday> all});

final FutureProvider<BirthdaysState> contactBirthdaysProvider =
    FutureProvider.autoDispose<BirthdaysState>((ref) async {
      final device = ref.watch(deviceDataProvider);
      if (!await device.hasContactsPermission()) {
        return (permission: false, all: const <ContactBirthday>[]);
      }
      return (permission: true, all: await device.birthdays());
    });

/// Al abrir la app: si el usuario lo pidió, agrega solos los cumpleaños
/// nuevos de sus contactos.
Future<void> importNewBirthdays(Ref ref) async {
  final settings = ref.read(settingsControllerProvider);
  if (!settings.autoBirthdays) return;
  try {
    final device = ref.read(deviceDataProvider);
    if (!await device.hasContactsPermission()) return;
    final importer = ref.read(birthdayImporterProvider);
    final pending = importer.pending(await device.birthdays());
    if (pending.isEmpty) return;
    final added = await importer.importAll(
      pending,
      time: settings.birthdayTime,
      daysBefore: settings.birthdayDaysBefore,
    );
    AppLogger.info('Cumpleaños agregados solos: $added');
  } on Object catch (error) {
    AppLogger.info('No se pudieron revisar los cumpleaños ($error)');
  }
}

final birthdaysStartupProvider = Provider<Future<void> Function()>(
  (ref) =>
      () => importNewBirthdays(ref),
);

/// Cumpleaños de los contactos del teléfono → recordatorios cada año.
class BirthdaysScreen extends ConsumerStatefulWidget {
  const BirthdaysScreen({super.key});

  @override
  ConsumerState<BirthdaysScreen> createState() => _BirthdaysScreenState();
}

class _BirthdaysScreenState extends ConsumerState<BirthdaysScreen> {
  /// Claves elegidas para agregar (por defecto, todos los nuevos).
  Set<String>? _selected;
  bool _busy = false;

  Future<void> _requestPermission() async {
    await ref.read(deviceDataProvider).requestContactsPermission();
    ref.invalidate(contactBirthdaysProvider);
  }

  Future<void> _import(List<ContactBirthday> birthdays) async {
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final settings = ref.read(settingsControllerProvider);
    setState(() => _busy = true);
    final added = await ref
        .read(birthdayImporterProvider)
        .importAll(
          birthdays,
          time: settings.birthdayTime,
          daysBefore: settings.birthdayDaysBefore,
        );
    if (!mounted) return;
    setState(() {
      _busy = false;
      _selected = null;
    });
    ref.invalidate(contactBirthdaysProvider);
    messenger.showSnackBar(
      SnackBar(content: Text(l10n.birthdaysAdded(added))),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final settings = ref.watch(settingsControllerProvider);
    final controller = ref.read(settingsControllerProvider.notifier);
    final state = ref.watch(contactBirthdaysProvider);
    final importer = ref.read(birthdayImporterProvider);
    final now = ref.read(clockProvider).now();

    return Scaffold(
      appBar: AppBar(title: Text(l10n.birthdaysTitle)),
      body: switch (state) {
        AsyncData(:final value) when !value.permission => EmptyState(
          icon: Icons.cake_outlined,
          title: l10n.birthdaysPermissionTitle,
          message: l10n.birthdaysPermissionBody,
          action: FilledButton(
            onPressed: () => unawaited(_requestPermission()),
            child: Text(l10n.birthdaysAllow),
          ),
        ),
        AsyncData(:final value) => _content(
          context,
          value.all,
          importer,
          settings,
          controller,
          now,
        ),
        AsyncError() => EmptyState(
          icon: Icons.error_outline,
          title: l10n.errorGeneric,
        ),
        _ => const Center(child: CircularProgressIndicator()),
      },
    );
  }

  Widget _content(
    BuildContext context,
    List<ContactBirthday> all,
    BirthdayImporter importer,
    AppSettings settings,
    SettingsController controller,
    DateTime now,
  ) {
    final l10n = context.l10n;
    final imported = importer.imported();
    final pending = [
      for (final b in all)
        if (!imported.contains(b.key)) b,
    ];
    final selected = _selected ??= {for (final b in pending) b.key};
    final toImport = [
      for (final b in pending)
        if (selected.contains(b.key)) b,
    ];
    final sorted = [...all]..sort((a, b) => a.next(now).compareTo(b.next(now)));

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: [
        Text(
          l10n.birthdaysIntro,
          style: context.textTheme.bodyMedium?.copyWith(
            color: context.colors.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 8),
        Card(
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.schedule),
                title: Text(l10n.birthdaysTime),
                trailing: Text(
                  l10n.time(
                    DateTime(
                      2000,
                      1,
                      1,
                      settings.birthdayTime.hour,
                      settings.birthdayTime.minute,
                    ),
                  ),
                ),
                onTap: () async {
                  final picked = await showTimePicker(
                    context: context,
                    initialTime: TimeOfDay(
                      hour: settings.birthdayTime.hour,
                      minute: settings.birthdayTime.minute,
                    ),
                  );
                  if (picked == null) return;
                  controller.update(
                    (s) => s.copyWith(
                      birthdayTime: DayTime(picked.hour, picked.minute),
                    ),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.notifications_active_outlined),
                title: Text(l10n.birthdaysBefore),
                trailing: DropdownButton<int>(
                  value: settings.birthdayDaysBefore,
                  underline: const SizedBox.shrink(),
                  items: [
                    for (final days in AppSettings.birthdayDaysOptions)
                      DropdownMenuItem(
                        value: days,
                        child: Text(l10n.birthdaysDays(days)),
                      ),
                  ],
                  onChanged: (days) => controller.update(
                    (s) => s.copyWith(birthdayDaysBefore: days),
                  ),
                ),
              ),
              SwitchListTile(
                secondary: const Icon(Icons.autorenew),
                title: Text(l10n.birthdaysAuto),
                subtitle: Text(l10n.birthdaysAutoSubtitle),
                value: settings.autoBirthdays,
                onChanged: (v) =>
                    controller.update((s) => s.copyWith(autoBirthdays: v)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (all.isEmpty)
          EmptyState(
            icon: Icons.cake_outlined,
            title: l10n.birthdaysEmpty,
            message: l10n.birthdaysEmptyBody,
          )
        else ...[
          FilledButton.icon(
            onPressed: _busy || toImport.isEmpty
                ? null
                : () => unawaited(_import(toImport)),
            icon: const Icon(Icons.cake),
            label: Text(l10n.birthdaysAdd(toImport.length)),
          ),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                for (final b in sorted)
                  imported.contains(b.key)
                      ? ListTile(
                          leading: const Icon(Icons.check_circle_outline),
                          title: Text(b.name),
                          subtitle: Text(
                            '${l10n.relativeDay(b.next(now), now)} · '
                            '${l10n.birthdaysAlready}',
                          ),
                        )
                      : CheckboxListTile(
                          value: selected.contains(b.key),
                          onChanged: (v) => setState(() {
                            v ?? false
                                ? selected.add(b.key)
                                : selected.remove(b.key);
                          }),
                          title: Text(b.name),
                          subtitle: Text(
                            [
                              l10n.relativeDay(b.next(now), now),
                              if (b.ageOn(b.next(now)) case final age?)
                                l10n.birthdaysTurns(age),
                            ].join(' · '),
                          ),
                        ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
