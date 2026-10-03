import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:viernes/app/router/routes.dart';
import 'package:viernes/core/extensions/context_x.dart';
import 'package:viernes/features/account/presentation/account_actions.dart';
import 'package:viernes/features/account/presentation/account_providers.dart';

/// Primera pantalla: invita a iniciar sesión con Google para respaldar los
/// datos, sin obligar (se puede usar sin cuenta).
class WelcomeScreen extends ConsumerStatefulWidget {
  const WelcomeScreen({super.key});

  @override
  ConsumerState<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends ConsumerState<WelcomeScreen> {
  bool _busy = false;

  Future<void> _signIn() async {
    setState(() => _busy = true);
    final ok = await AccountActions.signIn(context, ref);
    if (!mounted) return;
    setState(() => _busy = false);
    if (ok) await _continue();
  }

  Future<void> _continue() async {
    await ref.read(accountBindingProvider).markWelcomeSeen();
    if (mounted) context.go(AppRoutes.home);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = context.colors;
    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: constraints.maxHeight - 64,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    children: [
                      const SizedBox(height: 24),
                      CircleAvatar(
                        radius: 44,
                        backgroundColor: colors.primaryContainer,
                        child: Icon(
                          Icons.mic_rounded,
                          size: 44,
                          color: colors.onPrimaryContainer,
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        l10n.welcomeTitle,
                        style: context.textTheme.headlineMedium,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        l10n.welcomeSubtitle,
                        style: context.textTheme.bodyLarge?.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 32),
                      _Benefit(
                        icon: Icons.cloud_done_outlined,
                        text: l10n.welcomeBenefitBackup,
                      ),
                      _Benefit(
                        icon: Icons.phonelink_setup_outlined,
                        text: l10n.welcomeBenefitRestore,
                      ),
                      _Benefit(
                        icon: Icons.lock_outline,
                        text: l10n.welcomeBenefitPrivate,
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      FilledButton.icon(
                        onPressed: _busy ? null : () => unawaited(_signIn()),
                        icon: _busy
                            ? const SizedBox.square(
                                dimension: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.account_circle),
                        label: Text(l10n.welcomeGoogle),
                        style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(52),
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: _busy ? null : () => unawaited(_continue()),
                        child: Text(l10n.welcomeSkip),
                      ),
                      Text(
                        l10n.welcomeSkipNote,
                        style: context.textTheme.bodySmall?.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Benefit extends StatelessWidget {
  const _Benefit({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, color: context.colors.primary),
          const SizedBox(width: 16),
          Expanded(child: Text(text, style: context.textTheme.bodyLarge)),
        ],
      ),
    );
  }
}
