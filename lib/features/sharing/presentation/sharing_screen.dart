import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:viernes/app/providers.dart';
import 'package:viernes/app/router/routes.dart';
import 'package:viernes/core/extensions/context_x.dart';
import 'package:viernes/core/widgets/empty_state.dart';
import 'package:viernes/core/widgets/liquid.dart';
import 'package:viernes/features/account/presentation/account_actions.dart';
import 'package:viernes/features/account/presentation/account_providers.dart';
import 'package:viernes/features/reminders/presentation/reminder_formatters.dart';
import 'package:viernes/features/sharing/domain/sharing_models.dart';
import 'package:viernes/features/sharing/presentation/friend_invite_screen.dart';
import 'package:viernes/features/sharing/presentation/sharing_providers.dart';

/// Compartir con otras personas: listas, recordatorios enviados y contactos.
class SharingScreen extends ConsumerWidget {
  const SharingScreen({this.initialTab = 0, super.key});

  final int initialTab;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final user = ref.watch(authStateProvider).value;
    if (user == null) {
      return LiquidScaffold(
        appBar: AppBar(title: Text(l10n.sharingTitle)),
        body: EmptyState(
          icon: Icons.group_outlined,
          title: l10n.sharingSignIn,
          message: l10n.sharingSignInSubtitle,
          action: FilledButton(
            onPressed: () => unawaited(AccountActions.signIn(context, ref)),
            child: Text(l10n.welcomeGoogle),
          ),
        ),
      );
    }
    return DefaultTabController(
      length: 3,
      initialIndex: initialTab,
      child: LiquidScaffold(
        appBar: AppBar(
          title: Text(l10n.sharingTitle),
          bottom: TabBar(
            tabs: [
              Tab(text: l10n.sharingTabLists),
              Tab(text: l10n.sharingTabSent),
              Tab(text: l10n.sharingTabContacts),
            ],
          ),
        ),
        body: const TabBarView(
          children: [_ListsTab(), _SentTab(), _ContactsTab()],
        ),
      ),
    );
  }
}

class _ListsTab extends ConsumerWidget {
  const _ListsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final lists = ref.watch(sharedListsProvider);
    return LiquidScaffold(
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'new-list',
        onPressed: () => unawaited(_create(context, ref)),
        icon: const Icon(Icons.playlist_add),
        label: Text(l10n.listsNew),
      ),
      body: switch (lists) {
        AsyncData(:final value) when value.isEmpty => EmptyState(
          icon: Icons.checklist,
          title: l10n.listsEmpty,
          message: l10n.listsEmptySubtitle,
        ),
        AsyncData(:final value) => ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
          children: [
            for (final list in value)
              Card(
                child: ListTile(
                  leading: const Icon(Icons.checklist),
                  title: Text(list.name),
                  subtitle: Text(l10n.listsMembers(list.memberEmails.length)),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () =>
                      unawaited(context.push(AppRoutes.sharedList(list.id))),
                ),
              ),
          ],
        ),
        AsyncError() => EmptyState(
          icon: Icons.cloud_off_outlined,
          title: l10n.sharingOffline,
        ),
        _ => const Center(child: CircularProgressIndicator()),
      },
    );
  }

  Future<void> _create(BuildContext context, WidgetRef ref) async {
    final l10n = context.l10n;
    final name = await _askText(
      context,
      title: l10n.listsNew,
      label: l10n.listsName,
      hint: l10n.listsNameHint,
    );
    final user = ref.read(authStateProvider).value;
    if (name == null || user == null || user.email == null) return;
    await ref
        .read(sharingRepositoryProvider)
        .createList(
          SharedList(
            id: ref.read(idGeneratorProvider).next(),
            name: name,
            ownerUid: user.uid,
            memberEmails: [user.email!.toLowerCase()],
            createdAt: ref.read(clockProvider).now(),
          ),
        );
  }
}

class _SentTab extends ConsumerWidget {
  const _SentTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final sent = ref.watch(sentRemindersProvider).value ?? const [];
    final contacts = ref.watch(contactsProvider);
    if (sent.isEmpty) {
      return EmptyState(
        icon: Icons.send_outlined,
        title: l10n.sentEmpty,
        message: l10n.sentEmptySubtitle,
      );
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: [
        for (final r in sent)
          Card(
            child: ListTile(
              leading: Icon(
                switch (r.status) {
                  SharedStatus.done => Icons.check_circle,
                  SharedStatus.accepted => Icons.mark_email_read_outlined,
                  SharedStatus.cancelled => Icons.block,
                  SharedStatus.sent => Icons.schedule_send_outlined,
                },
                color: r.status == SharedStatus.done
                    ? context.colors.onPrimaryContainer
                    : null,
              ),
              title: Text(r.title),
              subtitle: Text(
                [
                  contacts
                          .where((c) => c.email == r.toEmail)
                          .map((c) => c.name)
                          .firstOrNull ??
                      r.toEmail,
                  l10n.dayAndTime(r.dueAt, r.dueAt),
                  switch (r.status) {
                    SharedStatus.done => l10n.sentDone,
                    SharedStatus.accepted => l10n.sentAccepted,
                    SharedStatus.cancelled => l10n.sentCancelled,
                    SharedStatus.sent => l10n.sentPending,
                  },
                ].join(' · '),
              ),
              trailing: r.status == SharedStatus.sent
                  ? IconButton(
                      tooltip: l10n.actionCancel,
                      icon: const Icon(Icons.close),
                      onPressed: () => unawaited(
                        ref
                            .read(sharingRepositoryProvider)
                            .setStatus(r.id, SharedStatus.cancelled),
                      ),
                    )
                  : null,
            ),
          ),
      ],
    );
  }
}

class _ContactsTab extends ConsumerWidget {
  const _ContactsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final contacts = ref.watch(contactsProvider);
    return LiquidScaffold(
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          const InviteCard(),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => unawaited(_add(context, ref)),
              icon: const Icon(Icons.alternate_email_rounded, size: 18),
              label: Text(l10n.contactsAddByEmail),
            ),
          ),
          if (contacts.isEmpty)
            EmptyState(
              icon: Icons.contacts_outlined,
              title: l10n.contactsEmpty,
              message: l10n.contactsEmptySubtitle,
            )
          else
            for (final c in contacts)
              Card(
                child: ListTile(
                  leading: CircleAvatar(
                    child: Text(c.name.characters.first.toUpperCase()),
                  ),
                  title: Text(c.name),
                  subtitle: Text(c.email),
                  trailing: IconButton(
                    tooltip: l10n.actionDelete,
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () => unawaited(
                      ref.read(contactsProvider.notifier).remove(c),
                    ),
                  ),
                ),
              ),
        ],
      ),
    );
  }

  Future<void> _add(BuildContext context, WidgetRef ref) async {
    final contact = await showDialog<Contact>(
      context: context,
      builder: (context) => const _ContactDialog(),
    );
    if (contact != null) {
      await ref.read(contactsProvider.notifier).save(contact);
    }
  }
}

class _ContactDialog extends StatefulWidget {
  const _ContactDialog();

  @override
  State<_ContactDialog> createState() => _ContactDialogState();
}

class _ContactDialogState extends State<_ContactDialog> {
  final _name = TextEditingController();
  final _email = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AlertDialog(
      title: Text(l10n.contactsAdd),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(l10n.contactsHint),
          const SizedBox(height: 12),
          TextField(
            controller: _name,
            autofocus: true,
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(labelText: l10n.contactsName),
          ),
          TextField(
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            decoration: InputDecoration(labelText: l10n.contactsEmail),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.actionCancel),
        ),
        FilledButton(
          onPressed: () {
            final name = _name.text.trim();
            final email = _email.text.trim().toLowerCase();
            if (name.isEmpty || !email.contains('@')) return;
            Navigator.of(context).pop(Contact(name: name, email: email));
          },
          child: Text(l10n.actionSave),
        ),
      ],
    );
  }
}

/// Pide un texto corto. Devuelve nulo si se cancela.
Future<String?> _askText(
  BuildContext context, {
  required String title,
  required String label,
  String? hint,
  TextInputType? keyboard,
}) async {
  final controller = TextEditingController();
  final result = await showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: TextField(
        controller: controller,
        autofocus: true,
        keyboardType: keyboard,
        textCapitalization: TextCapitalization.sentences,
        decoration: InputDecoration(labelText: label, hintText: hint),
        onSubmitted: (value) => Navigator.of(context).pop(value),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(context.l10n.actionCancel),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(controller.text),
          child: Text(context.l10n.actionSave),
        ),
      ],
    ),
  );
  controller.dispose();
  final text = result?.trim();
  return text == null || text.isEmpty ? null : text;
}

/// Para que la pantalla de la lista reutilice el diálogo.
Future<String?> askSharingText(
  BuildContext context, {
  required String title,
  required String label,
  String? hint,
  TextInputType? keyboard,
}) => _askText(
  context,
  title: title,
  label: label,
  hint: hint,
  keyboard: keyboard,
);
