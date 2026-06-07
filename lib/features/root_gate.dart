import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/settings.dart';
import 'history/history_screen.dart';
import 'lock/lock_screen.dart';
import 'onboarding/onboarding_screen.dart';

/// Decides the first screen once settings have loaded: onboarding on first run,
/// the lock screen when app lock is on and the session is locked, otherwise the
/// history. Waiting for the async settings avoids a wrong-screen flash.
class RootGate extends ConsumerWidget {
  const RootGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsControllerProvider);

    return settings.when(
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      // Fail open to history rather than locking the user out on a read error.
      error: (_, _) => const HistoryScreen(),
      data: (s) {
        if (!s.onboarded) return const OnboardingScreen();
        final unlocked = ref.watch(sessionUnlockedProvider);
        if (s.lockEnabled && !unlocked) return const LockScreen();
        return const HistoryScreen();
      },
    );
  }
}
