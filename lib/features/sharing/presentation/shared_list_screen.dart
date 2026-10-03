import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:viernes/app/providers.dart';
import 'package:viernes/core/extensions/context_x.dart';
import 'package:viernes/core/widgets/empty_state.dart';
import 'package:viernes/core/widgets/liquid.dart';
import 'package:viernes/features/account/presentation/account_providers.dart';
import 'package:viernes/features/sharing/domain/sharing_models.dart';
import 'package:viernes/features/sharing/presentation/sharing_providers.dart';
import 'package:viernes/features/sharing/presentation/sharing_screen.dart';

/// Una lista compartida: se actualiza en vivo para todos sus miembros.
class SharedListScreen extends ConsumerStatefulWidget {
  const SharedListScreen({required this.listId, super.key});

  final String listId;

  @override
  ConsumerState<SharedListScreen> createState() => _SharedListScreenState();
}

class _SharedListScreenState extends ConsumerState<SharedListScreen> {
  final _input = TextEditingController();

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  SharedList? get _list => ref
      .watch(sharedListsProvider)
      .value
      ?.where((l) => l.id == widget.listId)
      .firstOrNull;

  Future<void> _add() async {
    final text = _input.text.trim();
    if (text.isEmpty) return;
    _input.clear();
    final user = ref.read(authStateProvider).value;
    await ref.read(sharingRepositoryProvider).addItems(widget.listId, [
      SharedListItem(
        id: ref.read(idGeneratorProvider).next(),
        text: text,
        addedBy: user?.firstName ?? user?.email ?? '',
        addedAt: ref.read(clockProvider).now(),
      ),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final list = _list;
    final items = ref.watch(listItemsProvider(widget.listId)).value ?? const [];
    final repository = ref.read(sharingRepositoryProvider);
    final user = ref.watch(authStateProvider).value;
    return LiquidScaffold(
      appBar: AppBar(
        title: Text(list?.name ?? ''),
        actions: [
          IconButton(
            tooltip: l10n.listsShare,
            icon: const Icon(Icons.person_add_alt),
            onPressed: list == null ? null : () => unawaited(_share(list)),
          ),
          PopupMenuButton<String>(
            onSelected: (value) async {
              if (list == null || user == null) return;
              if (value == 'clear') {
                for (final item in items.where((i) => i.done)) {
                  await repository.deleteItem(widget.listId, item.id);
                }
              } else if (value == 'delete' && list.ownerUid == user.uid) {
                await repository.deleteList(widget.listId);
                if (context.mounted) context.pop();
              } else if (value == 'leave') {
                await repository.setMembers(widget.listId, [
                  for (final e in list.memberEmails)
                    if (e != user.email?.toLowerCase()) e,
                ]);
                if (context.mounted) context.pop();
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(value: 'clear', child: Text(l10n.listsClearDone)),
              if (list != null && list.ownerUid == user?.uid)
                PopupMenuItem(value: 'delete', child: Text(l10n.listsDelete))
              else
                PopupMenuItem(value: 'leave', child: Text(l10n.listsLeave)),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              controller: _input,
              textCapitalization: TextCapitalization.sentences,
              textInputAction: TextInputAction.done,
              decoration: InputDecoration(
                hintText: l10n.listsAddItem,
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.add),
                  onPressed: () => unawaited(_add()),
                ),
              ),
              onSubmitted: (_) => unawaited(_add()),
            ),
          ),
          Expanded(
            child: items.isEmpty
                ? EmptyState(
                    icon: Icons.checklist,
                    title: l10n.listsNoItems,
                    message: l10n.listsNoItemsSubtitle,
                  )
                : ListView(
                    padding: const EdgeInsets.fromLTRB(8, 0, 8, 32),
                    children: [
                      for (final item in items)
                        Dismissible(
                          key: ValueKey(item.id),
                          onDismissed: (_) => unawaited(
                            repository.deleteItem(widget.listId, item.id),
                          ),
                          child: CheckboxListTile(
                            value: item.done,
                            onChanged: (value) => unawaited(
                              repository.setItemDone(
                                widget.listId,
                                item.id,
                                done: value ?? false,
                              ),
                            ),
                            title: Text(
                              item.text,
                              style: item.done
                                  ? const TextStyle(
                                      decoration: TextDecoration.lineThrough,
                                    )
                                  : null,
                            ),
                            subtitle: _subtitle(context, item, user?.email),
                            secondary: IconButton(
                              tooltip: l10n.listsAssign,
                              icon: Icon(
                                item.assignedTo == null
                                    ? Icons.person_add_alt_1_outlined
                                    : Icons.assignment_ind,
                              ),
                              onPressed: list == null
                                  ? null
                                  : () => unawaited(_assign(list, item)),
                            ),
                          ),
                        ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget? _subtitle(
    BuildContext context,
    SharedListItem item,
    String? myEmail,
  ) {
    final l10n = context.l10n;
    final parts = [
      if (item.assignedTo != null)
        item.assignedTo == myEmail?.toLowerCase()
            ? l10n.listsForYou
            : l10n.listsFor(item.assignedName ?? item.assignedTo!),
      if (item.addedBy.isNotEmpty) l10n.listsAddedBy(item.addedBy),
    ];
    return parts.isEmpty ? null : Text(parts.join(' · '));
  }

  /// Elige a quién le toca entre los miembros de la lista.
  Future<void> _assign(SharedList list, SharedListItem item) async {
    final l10n = context.l10n;
    final contacts = ref.read(contactsProvider);
    final user = ref.read(authStateProvider).value;
    final me = user?.email?.toLowerCase();
    String nameOf(String email) {
      if (email == me) return user?.firstName ?? email;
      return contacts.where((c) => c.email == email).firstOrNull?.name ?? email;
    }

    // Vacío = sin asignar.
    final picked = await showDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text(l10n.listsAssignTitle(item.text)),
        children: [
          for (final email in list.memberEmails)
            SimpleDialogOption(
              onPressed: () => Navigator.of(context).pop(email),
              child: ListTile(
                leading: Icon(
                  email == item.assignedTo
                      ? Icons.radio_button_checked
                      : Icons.radio_button_unchecked,
                ),
                title: Text(email == me ? l10n.listsMe : nameOf(email)),
                subtitle: Text(email),
              ),
            ),
          SimpleDialogOption(
            onPressed: () => Navigator.of(context).pop(''),
            child: ListTile(
              leading: const Icon(Icons.person_off_outlined),
              title: Text(l10n.listsNobody),
            ),
          ),
        ],
      ),
    );
    if (picked == null) return;
    await ref
        .read(sharingRepositoryProvider)
        .assignItem(
          widget.listId,
          item.id,
          email: picked.isEmpty ? null : picked,
          name: picked.isEmpty ? null : nameOf(picked),
        );
  }

  Future<void> _share(SharedList list) async {
    final l10n = context.l10n;
    final contacts = ref.read(contactsProvider);
    final email = await showDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text(l10n.listsShare),
        children: [
          for (final c in contacts)
            if (!list.memberEmails.contains(c.email))
              SimpleDialogOption(
                onPressed: () => Navigator.of(context).pop(c.email),
                child: ListTile(title: Text(c.name), subtitle: Text(c.email)),
              ),
          SimpleDialogOption(
            onPressed: () => Navigator.of(context).pop(''),
            child: ListTile(
              leading: const Icon(Icons.alternate_email),
              title: Text(l10n.listsShareByEmail),
            ),
          ),
        ],
      ),
    );
    if (email == null || !mounted) return;
    final target = email.isNotEmpty
        ? email
        : await askSharingText(
            context,
            title: l10n.listsShare,
            label: l10n.contactsEmail,
            keyboard: TextInputType.emailAddress,
          );
    if (target == null || !target.contains('@')) return;
    await ref.read(sharingRepositoryProvider).setMembers(list.id, [
      ...list.memberEmails,
      target.toLowerCase(),
    ]);
  }
}
