import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/providers.dart';
import 'router.dart';
import 'theme.dart';

/// Root widget. Wires Material 3 theming (with dynamic color when available)
/// to the go_router shell.
class SniptApp extends ConsumerWidget {
  const SniptApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Registering the bridge connects the native capture engine to the
    // repository for the app's lifetime.
    ref.watch(captureBridgeProvider);
    return DynamicColorBuilder(
      builder: (lightDynamic, darkDynamic) {
        return MaterialApp.router(
          title: 'snipt',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light(lightDynamic?.harmonized()),
          darkTheme: AppTheme.dark(darkDynamic?.harmonized()),
          themeMode: ThemeMode.system,
          routerConfig: appRouter,
        );
      },
    );
  }
}
