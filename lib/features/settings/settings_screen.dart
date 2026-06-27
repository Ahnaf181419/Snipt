import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
    // Sync the stored captureServiceEnabled flag with the actual running state
    // so the switch isn't stale after the OS kills the service.
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
    } catch (_) {
      // Platform not available in tests — ignore.
    }
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
      // Outcome (success / error) flows through purchaseStatusProvider
      // and the bootstrap listener, so no UI handling needed here beyond
      // telling the user we kicked off the flow.
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
          const _SectionHeader('Snipt Pro'),
          if (isPro) ...[
            const ListTile(
              leading: Icon(Icons.workspace_premium, color: Colors.amber),
              title: Text('Snipt Pro is active'),
              subtitle: Text(
                'Thanks for supporting local-first clipboard history.',
              ),
            ),
          ] else ...[
            const _ProBenefitsTile(),
            ListTile(
              leading: const Icon(Icons.shopping_bag_outlined),
              title: const Text('Upgrade to Pro'),
              subtitle: Text(_upgradeSubtitle(purchaseStatus)),
              trailing: purchaseStatus == PurchaseStatus.pending
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.chevron_right),
              onTap: purchaseStatus == PurchaseStatus.pending
                  ? null
                  : _buyPro,
            ),
            ListTile(
              leading: const Icon(Icons.refresh),
              title: const Text('Restore purchases'),
              onTap: _restorePurchases,
            ),
          ],
          const _SectionHeader('Capture'),
          SwitchListTile(
            title: const Text('Capture service'),
            subtitle: const Text(
              'Runs a persistent notification with a one-tap Capture action.',
            ),
            value: settings.captureServiceEnabled,
            onChanged: _toggleService,
          ),
          ListTile(
            title: const Text('Floating bubble permission'),
            subtitle: const Text('Allow drawing over other apps.'),
            trailing: const Icon(Icons.open_in_new),
            onTap: () => bridge.host.requestOverlayPermission(),
          ),
          const _SectionHeader('Storage'),
          ListTile(
            title: const Text('Keep history for'),
            subtitle: const Text('Pinned clips are never auto-deleted.'),
            trailing: DropdownButton<int>(
              value: settings.retentionDays,
              onChanged: (v) {
                if (v != null) {
                  ref
                      .read(settingsControllerProvider.notifier)
                      .setRetentionDays(v);
                }
              },
              items: [
                for (final e in _retentionOptions.entries)
                  DropdownMenuItem(value: e.key, child: Text(e.value)),
              ],
            ),
          ),
          const _SectionHeader('About'),
          const ListTile(
            leading: Icon(Icons.shield_outlined),
            title: Text('Local-first & private'),
            subtitle: Text(
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

/// Compact list of Pro benefits. Kept here (not in the upgrade dialog) so
/// the value is visible before the user commits to opening Google Play.
class _ProBenefitsTile extends StatelessWidget {
  const _ProBenefitsTile();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Pro unlocks',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: scheme.primary,
                ),
          ),
          const SizedBox(height: 4),
          const Text('• Unlimited clip history (free tier: 200)'),
          const Text('• Export & import your clips'),
          const Text('• Auto-clear timer for the system clipboard'),
          const Text('• Home-screen quick-capture widget'),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
      child: Text(
        title.toUpperCase(),
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: Theme.of(context).colorScheme.primary,
              letterSpacing: 0.8,
            ),
      ),
    );
  }
}
