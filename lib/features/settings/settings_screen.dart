import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../data/billing/billing_providers.dart';
import '../../data/billing/billing_service.dart';
import '../../data/providers.dart';
import '../../data/settings.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  static const _retentionOptions = {
    7: '7 days',
    30: '30 days',
    90: '90 days',
    0: 'Forever',
  };

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _syncServiceState());
  }

  Future<void> _syncServiceState() async {
    final bridge = ref.read(captureBridgeProvider);
    final controller = ref.read(settingsControllerProvider.notifier);
    final settings = ref.read(settingsControllerProvider).value;
    if (settings == null) return;
    try {
      final running = await bridge.host.isServiceRunning();
      if (running != settings.captureServiceEnabled) {
        await controller.setCaptureServiceEnabled(running);
      }
    } catch (_) {}
  }

  Future<void> _toggleService(bool on) async {
    final bridge = ref.read(captureBridgeProvider);
    final controller = ref.read(settingsControllerProvider.notifier);
    final messenger = ScaffoldMessenger.of(context);
    try {
      if (on) {
        await bridge.host.startService();
      } else {
        await bridge.host.stopService();
      }
      await controller.setCaptureServiceEnabled(on);
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Could not ${on ? 'start' : 'stop'} service: $e')),
      );
    }
  }

  Future<void> _buyPro() async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(billingServiceProvider).buyPro();
      messenger.showSnackBar(
        const SnackBar(content: Text('Opening Google Play…')),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Could not start purchase: $e')),
      );
    }
  }

  Future<void> _restorePurchases() async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(billingServiceProvider).restore();
      messenger.showSnackBar(
        const SnackBar(content: Text('Restoring purchases…')),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Could not restore: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    final settings =
        ref.watch(settingsControllerProvider).value ?? const AppSettings();
    final bridge = ref.read(captureBridgeProvider);
    final isPro = ref.watch(isProProvider);
    final purchaseStatus =
        ref.watch(purchaseStatusProvider).value ?? PurchaseStatus.notOwned;

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          _SectionHeader('Snipt Pro', theme: theme),
          if (isPro) ...[
            ListTile(
              leading: const Icon(LucideIcons.crown, color: Colors.amber),
              title: const Text('Snipt Pro is active'),
              subtitle: const Text(
                'Thanks for supporting local-first clipboard history.',
              ),
            ),
          ] else ...[
            const _ProBenefitsTile(),
            ListTile(
              leading: const Icon(LucideIcons.shoppingBag),
              title: const Text('Upgrade to Pro'),
              subtitle: Text(_upgradeSubtitle(purchaseStatus)),
              trailing: purchaseStatus == PurchaseStatus.pending
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(LucideIcons.chevronRight),
              onTap: purchaseStatus == PurchaseStatus.pending
                  ? null
                  : _buyPro,
            ),
            ListTile(
              leading: const Icon(LucideIcons.refreshCw),
              title: const Text('Restore purchases'),
              onTap: _restorePurchases,
            ),
          ],
          _SectionHeader('Capture', theme: theme),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Capture service',
                          style: theme.textTheme.p
                              .copyWith(fontWeight: FontWeight.w500)),
                      const SizedBox(height: 2),
                      Text(
                        'Runs a persistent notification with a one-tap Capture action.',
                        style: theme.textTheme.muted
                            .copyWith(color: theme.colorScheme.mutedForeground),
                      ),
                    ],
                  ),
                ),
                ShadSwitch(
                  value: settings.captureServiceEnabled,
                  onChanged: _toggleService,
                ),
              ],
            ),
          ),
          ListTile(
            leading: const Icon(LucideIcons.layers),
            title: const Text('Floating bubble permission'),
            subtitle: const Text('Allow drawing over other apps.'),
            trailing: const Icon(LucideIcons.externalLink),
            onTap: () => bridge.host.requestOverlayPermission(),
          ),
          _SectionHeader('Storage', theme: theme),
          ListTile(
            title: const Text('Keep history for'),
            subtitle: const Text('Pinned clips are never auto-deleted.'),
            trailing: ShadSelect<int>(
              options: [
                for (final e in _retentionOptions.entries)
                  ShadOption(
                    value: e.key,
                    child: Text(e.value),
                  ),
              ],
              selectedOptionBuilder: (context, value) =>
                  Text(_retentionOptions[value] ?? '30 days'),
              initialValue: settings.retentionDays,
              onChanged: (v) {
                if (v != null) {
                  ref
                      .read(settingsControllerProvider.notifier)
                      .setRetentionDays(v);
                }
              },
            ),
          ),
          _SectionHeader('About', theme: theme),
          ListTile(
            leading: const Icon(LucideIcons.shieldCheck),
            title: const Text('Local-first & private'),
            subtitle: const Text(
              'Clips are stored only on this device. Nothing is uploaded.\n\n'
              'Android blocks background clipboard reads, so snipt captures '
              'via the Capture action, the Quick-Settings tile, the share '
              'sheet, or the in-app Capture button.',
            ),
            isThreeLine: true,
          ),
        ],
      ),
    );
  }

  String _upgradeSubtitle(PurchaseStatus status) {
    switch (status) {
      case PurchaseStatus.pending:
        return 'Waiting for Google Play…';
      case PurchaseStatus.error:
        return 'Last attempt failed — tap to retry';
      case PurchaseStatus.owned:
        return 'You already own Pro. Tap Restore purchases above.';
      case PurchaseStatus.notOwned:
        return 'Unlock unlimited clips, export, and more.';
    }
  }
}

class _ProBenefitsTile extends StatelessWidget {
  const _ProBenefitsTile();

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Pro unlocks',
            style: theme.textTheme.small.copyWith(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text('• Unlimited clip history (free tier: 200)',
              style: theme.textTheme.muted),
          Text('• Export & import your clips', style: theme.textTheme.muted),
          Text('• Auto-clear timer for the system clipboard',
              style: theme.textTheme.muted),
          Text('• Home-screen quick-capture widget',
              style: theme.textTheme.muted),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.title, {required this.theme});

  final String title;
  final ShadThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
      child: Text(
        title.toUpperCase(),
        style: theme.textTheme.small.copyWith(
          color: theme.colorScheme.primary,
          letterSpacing: 0.8,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
