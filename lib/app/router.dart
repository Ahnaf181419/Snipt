import 'package:go_router/go_router.dart';

import '../data/db/database.dart';
import '../features/detail/clip_detail_screen.dart';
import '../features/onboarding/onboarding_screen.dart';
import '../features/root_gate.dart';
import '../features/settings/settings_screen.dart';

/// Central route table. The home route is a gate that picks
/// onboarding / history based on loaded settings.
final GoRouter appRouter = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/',
      name: 'home',
      builder: (context, state) => const RootGate(),
    ),
    GoRoute(
      path: '/onboarding',
      name: 'onboarding',
      builder: (context, state) => const OnboardingScreen(),
    ),
    GoRoute(
      path: '/settings',
      name: 'settings',
      builder: (context, state) => const SettingsScreen(),
    ),
    GoRoute(
      path: '/detail',
      name: 'detail',
      // Redirect instead of crashing when `extra` is absent (e.g. deep link or
      // direct URL navigation without a Clip object).
      redirect: (context, state) =>
          state.extra is Clip ? null : '/',
      builder: (context, state) => ClipDetailScreen(clip: state.extra! as Clip),
    ),
  ],
);
