import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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

  @override
  Widget build(BuildContext context) {
    final settings =
        ref.watch(settingsControllerProvider).value ?? const AppSettings();
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
