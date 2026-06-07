import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_auth/local_auth.dart';

import '../../data/providers.dart';
import '../../data/settings.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  static const _retentionOptions = {
    7: '7 days',
    30: '30 days',
    90: '90 days',
    0: 'Forever',
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings =
        ref.watch(settingsControllerProvider).value ?? const AppSettings();
    final controller = ref.read(settingsControllerProvider.notifier);
    final bridge = ref.read(captureBridgeProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          const _SectionHeader('Capture'),
          SwitchListTile(
            title: const Text('Capture service'),
            subtitle: const Text(
              'Runs a persistent notification with a one-tap Capture action.',
            ),
            value: settings.captureServiceEnabled,
            onChanged: (on) async {
              if (on) {
                await bridge.host.startService();
              } else {
                await bridge.host.stopService();
              }
              await controller.setCaptureServiceEnabled(on);
            },
          ),
          ListTile(
            title: const Text('Floating bubble permission'),
            subtitle: const Text('Allow drawing over other apps.'),
            trailing: const Icon(Icons.open_in_new),
            onTap: () => bridge.host.requestOverlayPermission(),
          ),
          const _SectionHeader('Privacy'),
          SwitchListTile(
            title: const Text('App lock'),
            subtitle: const Text('Require biometrics / device PIN to open.'),
            value: settings.lockEnabled,
            onChanged: (on) => _toggleLock(context, controller, ref, on),
          ),
          ListTile(
            title: const Text('Keep history for'),
            subtitle: const Text('Pinned clips are never auto-deleted.'),
            trailing: DropdownButton<int>(
              value: settings.retentionDays,
              onChanged: (v) {
                if (v != null) controller.setRetentionDays(v);
              },
              items: [
                for (final e in _retentionOptions.entries)
                  DropdownMenuItem(value: e.key, child: Text(e.value)),
              ],
            ),
          ),
          const _SectionHeader('About'),
          const ListTile(
            leading: Icon(Icons.lock_outline),
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

  Future<void> _toggleLock(
    BuildContext context,
    SettingsController controller,
    WidgetRef ref,
    bool enable,
  ) async {
    if (!enable) {
      await controller.setLockEnabled(false);
      return;
    }
    final auth = LocalAuthentication();
    final messenger = ScaffoldMessenger.of(context);
    try {
      final canCheck = await auth.isDeviceSupported();
      if (!canCheck) {
        messenger.showSnackBar(
          const SnackBar(content: Text('No device lock available')),
        );
        return;
      }
      final ok = await auth.authenticate(
        localizedReason: 'Confirm to enable app lock',
      );
      if (ok) await controller.setLockEnabled(true);
    } on Exception catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Lock unavailable: $e')));
    }
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
