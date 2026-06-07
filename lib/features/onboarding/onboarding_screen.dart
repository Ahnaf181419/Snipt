import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers.dart';
import '../../data/settings.dart';

/// First-run explainer. We are deliberately honest about Android's clipboard
/// restriction instead of pretending capture is fully automatic.
class OnboardingScreen extends ConsumerWidget {
  const OnboardingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(settingsControllerProvider.notifier);
    final bridge = ref.read(captureBridgeProvider);
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const SizedBox(height: 24),
            Icon(Icons.content_paste_search, size: 72, color: scheme.primary),
            const SizedBox(height: 16),
            Text('Welcome to snipt',
                style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 12),
            Text(
              'Android does not let any app read the clipboard in the '
              'background. So snipt captures clips the moment you ask it to:',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 20),
            const _HowItWorks(
              icon: Icons.bolt,
              title: 'Capture action',
              body: 'Tap “Capture clip” in the notification or Quick-Settings '
                  'tile after copying.',
            ),
            const _HowItWorks(
              icon: Icons.ios_share,
              title: 'Share sheet',
              body: 'Share any text to snipt to save it.',
            ),
            const _HowItWorks(
              icon: Icons.add_circle_outline,
              title: 'In-app',
              body: 'Tap Capture inside snipt to grab the current clipboard.',
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              icon: const Icon(Icons.play_arrow),
              label: const Text('Enable capture service'),
              onPressed: () async {
                try {
                  await bridge.host.startService();
                  await controller.setCaptureServiceEnabled(true);
                } catch (_) {
                  // Silently continue — service can be re-enabled from Settings.
                  // Most common cause: POST_NOTIFICATIONS not yet granted on
                  // Android 13+ (the service still starts but without a visible
                  // notification until the permission is granted).
                }
              },
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              icon: const Icon(Icons.layers_outlined),
              label: const Text('Allow floating bubble (optional)'),
              onPressed: () => bridge.host.requestOverlayPermission(),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => controller.completeOnboarding(),
              child: const Text('Continue to history'),
            ),
          ],
        ),
      ),
    );
  }
}

class _HowItWorks extends StatelessWidget {
  const _HowItWorks({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Theme.of(context).colorScheme.secondary),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 2),
                Text(body, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
