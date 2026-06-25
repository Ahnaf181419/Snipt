import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/settings.dart';
import 'history/history_screen.dart';
import 'lock/lock_screen.dart';
import 'onboarding/onboarding_screen.dart';

/// Decides the first screen once settings have loaded: onboarding on first run,
/// the lock screen when app lock is on and the session is locked, otherwise the
/// history. Waiting for the async settings avoids a wrong-screen flash.
///
/// Also re-arms the app lock when the app is resumed from the background:
/// [sessionUnlockedProvider] is reset so the lock screen shows again if the
/// user had lock enabled and left the app.
class RootGate extends ConsumerStatefulWidget {
  const RootGate({super.key});

  @override
  ConsumerState<RootGate> createState() => _RootGateState();
}

class _RootGateState extends ConsumerState<RootGate>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // When the app returns to the foreground, re-arm the lock so a stranger
    // who picks up the device sees the lock screen, not clipboard contents.
    if (state == AppLifecycleState.resumed) {
      final settings = ref.read(settingsControllerProvider).value;
      if (settings != null && settings.lockEnabled) {
        ref.read(sessionUnlockedProvider.notifier).state = false;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
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
