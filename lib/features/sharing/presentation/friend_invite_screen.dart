import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:viernes/app/router/routes.dart';
import 'package:viernes/app/theme/app_theme.dart';
import 'package:viernes/core/extensions/context_x.dart';
import 'package:viernes/core/widgets/empty_state.dart';
import 'package:viernes/core/widgets/liquid.dart';
import 'package:viernes/features/account/presentation/account_actions.dart';
import 'package:viernes/features/account/presentation/account_providers.dart';
import 'package:viernes/features/sharing/domain/friend_invite.dart';
import 'package:viernes/features/sharing/presentation/sharing_providers.dart';

/// Se abre desde el enlace de invitación (o al pegarlo): un toque y quedan
/// agregados los dos.
class FriendInviteScreen extends ConsumerStatefulWidget {
  const FriendInviteScreen({required this.code, super.key});

  final String code;

  @override
  ConsumerState<FriendInviteScreen> createState() => _FriendInviteScreenState();
}

class _FriendInviteScreenState extends ConsumerState<FriendInviteScreen> {
  bool _busy = false;
  InviteResult? _result;

  Future<void> _accept(FriendInvite invite) async {
    setState(() => _busy = true);
    if (ref.read(authStateProvider).value == null) {
      final signedIn = await AccountActions.signIn(context, ref);
      if (!signedIn || !mounted) {
        if (mounted) setState(() => _busy = false);
        return;
      }
    }
    final result = await ref.read(friendInvitesProvider).accept(invite);
    if (mounted) {
      setState(() {
        _busy = false;
        _result = result;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final invite = FriendInvite.fromCode(widget.code);
    final p = LiquidPalette.of(context);
    return LiquidScaffold(
      appBar: AppBar(title: Text(l10n.inviteTitle)),
      body: invite == null
          ? EmptyState(
              icon: Icons.link_off_rounded,
              title: l10n.inviteInvalid,
              message: l10n.inviteInvalidBody,
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 40),
              children: [
                Center(
                  child: Container(
                    width: 96,
                    height: 96,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: p.accent,
                    ),
                    child: Text(
                      invite.name.characters.first.toUpperCase(),
                      style: context.textTheme.displaySmall?.copyWith(
                        color: p.onAccent,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  l10n.inviteFrom(invite.name),
                  textAlign: TextAlign.center,
                  style: context.textTheme.headlineMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  invite.email,
                  textAlign: TextAlign.center,
                  style: AppTheme.monoStyle(context.textTheme.bodyMedium),
                ),
                const SizedBox(height: 16),
                Text(
                  l10n.inviteExplain,
                  textAlign: TextAlign.center,
                  style: context.textTheme.bodyLarge,
                ),
                const SizedBox(height: 32),
                switch (_result) {
                  null => FilledButton.icon(
                    onPressed: _busy ? null : () => unawaited(_accept(invite)),
                    icon: _busy
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.person_add_alt_1_rounded),
                    label: Text(l10n.inviteAccept(invite.name)),
                  ),
                  InviteResult.self => _Outcome(
                    icon: Icons.info_outline_rounded,
                    text: l10n.inviteSelf,
                  ),
                  InviteResult.added => _Outcome(
                    icon: Icons.check_circle_rounded,
                    text: l10n.inviteAdded(invite.name),
                  ),
                  InviteResult.addedOnlyHere => _Outcome(
                    icon: Icons.check_circle_outline_rounded,
                    text: l10n.inviteAddedOnlyHere(invite.name),
                  ),
                },
                if (_result != null) ...[
                  const SizedBox(height: 16),
                  OutlinedButton(
                    onPressed: () => context.go(AppRoutes.sharingContacts),
                    child: Text(l10n.inviteSeeContacts),
                  ),
                ],
              ],
            ),
    );
  }
}

class _Outcome extends StatelessWidget {
  const _Outcome({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => LiquidGlass(
    padding: const EdgeInsets.all(18),
    child: Row(
      children: [
        Icon(icon, color: LiquidPalette.of(context).accentText),
        const SizedBox(width: 12),
        Expanded(child: Text(text, style: context.textTheme.bodyLarge)),
      ],
    ),
  );
}

/// Arriba de los contactos: invitar con un enlace o un código QR, o pegar la
/// invitación que alguien me mandó.
class InviteCard extends ConsumerWidget {
  const InviteCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final invite = ref.watch(friendInvitesProvider).mine();
    return LiquidGlass(
      radius: LiquidRadius.lg,
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(l10n.inviteCardTitle, style: context.textTheme.titleLarge),
          const SizedBox(height: 6),
          Text(l10n.inviteCardBody, style: context.textTheme.bodyMedium),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: invite == null
                      ? null
                      : () => unawaited(
                          SharePlus.instance.share(
                            ShareParams(
                              text: invite.message(),
                              subject: l10n.inviteShareSubject,
                            ),
                          ),
                        ),
                  icon: const Icon(Icons.ios_share_rounded),
                  label: Text(l10n.inviteShare),
                ),
              ),
              const SizedBox(width: 10),
              GlassIconButton(
                icon: Icons.qr_code_2_rounded,
                tooltip: l10n.inviteQr,
                onPressed: invite == null
                    ? null
                    : () => unawaited(_showQr(context, invite)),
              ),
            ],
          ),
          const SizedBox(height: 4),
          TextButton.icon(
            onPressed: () => unawaited(_paste(context)),
            icon: const Icon(Icons.content_paste_rounded, size: 18),
            label: Text(l10n.invitePaste),
          ),
        ],
      ),
    );
  }

  Future<void> _paste(BuildContext context) async {
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final router = GoRouter.of(context);
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final invite = FriendInvite.tryParse(data?.text);
    if (invite == null) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(l10n.invitePasteNothing)));
      return;
    }
    unawaited(router.push(AppRoutes.friendInvite(invite.code)));
  }

  Future<void> _showQr(BuildContext context, FriendInvite invite) =>
      showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(context.l10n.inviteQrTitle),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(LiquidRadius.md),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: QrImageView(
                    data: invite.link,
                    size: 220,
                    backgroundColor: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                context.l10n.inviteQrBody,
                textAlign: TextAlign.center,
                style: context.textTheme.bodyMedium,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(context.l10n.voiceClose),
            ),
          ],
        ),
      );
}
