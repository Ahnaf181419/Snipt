import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/billing/billing_providers.dart';
import '../data/settings.dart';
import 'history/history_screen.dart';
import 'onboarding/onboarding_screen.dart';

/// Decides the first screen once settings have loaded: onboarding on first
/// run, otherwise the history. Waiting for the async settings avoids a
/// wrong-screen flash.
///
/// Also touches [billingBootstrapProvider] so the purchase-restore runs
/// exactly once at startup. Keeping the touch here (rather than main.dart)
/// means it sits inside the same `ProviderScope` as the rest of the app.
class RootGate extends ConsumerWidget {
  const RootGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Touch the bootstrap so the restore and status listener are wired.
    // Returned value is unused.
    ref.watch(billingBootstrapProvider);
    final settings = ref.watch(settingsControllerProvider);

    return settings.when(
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      // Fail open to history rather than blocking the user on a read error.
      error: (_, _) => const HistoryScreen(),
      data: (s) {
        if (!s.onboarded) return const OnboardingScreen();
        return const HistoryScreen();
      },
    );
  }
}
