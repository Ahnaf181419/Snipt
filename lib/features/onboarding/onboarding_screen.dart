import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../data/providers.dart';
import '../../data/settings.dart';

/// First-run explainer. We are deliberately honest about Android's clipboard
/// restriction instead of pretending capture is fully automatic.
class OnboardingScreen extends ConsumerWidget {
  const OnboardingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = ShadTheme.of(context);
    final controller = ref.read(settingsControllerProvider.notifier);
    final bridge = ref.read(captureBridgeProvider);

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const SizedBox(height: 24),
            Icon(LucideIcons.clipboardList, size: 72, color: theme.colorScheme.primary),
            const SizedBox(height: 16),
            Text('Welcome to snipt', style: theme.textTheme.h3),
            const SizedBox(height: 12),
            Text(
              'Android does not let any app read the clipboard in the '
              'background. So snipt captures clips the moment you ask it to:',
              style: theme.textTheme.p,
            ),
            const SizedBox(height: 20),
            const _HowItWorks(
              icon: LucideIcons.zap,
              title: 'Capture action',
              body: 'Tap "Capture clip" in the notification or Quick-Settings '
                  'tile after copying.',
            ),
            const _HowItWorks(
              icon: LucideIcons.share,
              title: 'Share sheet',
              body: 'Share any text to snipt to save it.',
            ),
            const _HowItWorks(
              icon: LucideIcons.plus,
              title: 'In-app',
              body: 'Tap Capture inside snipt to grab the current clipboard.',
            ),
            const SizedBox(height: 24),
            ShadButton(
              leading: const Icon(LucideIcons.play),
              child: const Text('Enable capture service'),
              onPressed: () async {
                try {
                  await bridge.host.startService();
                  await controller.setCaptureServiceEnabled(true);
                } catch (_) {}
              },
            ),
            const SizedBox(height: 8),
            ShadButton.outline(
              leading: const Icon(LucideIcons.layers),
              child: const Text('Allow floating bubble (optional)'),
              onPressed: () => bridge.host.requestOverlayPermission(),
            ),
            const SizedBox(height: 8),
            ShadButton.raw(
              variant: ShadButtonVariant.ghost,
              child: const Text('Continue to history'),
              onPressed: () async {
                await controller.completeOnboarding();
                if (context.mounted) context.go('/');
              },
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
    final theme = ShadTheme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: theme.colorScheme.primary),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: theme.textTheme.p.copyWith(fontWeight: FontWeight.w500)),
                const SizedBox(height: 2),
                Text(body, style: theme.textTheme.muted),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
