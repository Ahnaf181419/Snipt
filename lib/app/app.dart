import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/foundation.dart';
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

    // In release mode, replace the default red error screen with a calm
    // fallback so users never see a stack trace.
    if (kReleaseMode) {
      ErrorWidget.builder = (details) => Material(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline, size: 48),
                  const SizedBox(height: 16),
                  Text(
                    'Something went wrong',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ],
              ),
            ),
          );
    }

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
