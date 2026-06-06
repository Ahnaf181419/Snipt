import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/material.dart';

import 'router.dart';
import 'theme.dart';

/// Root widget. Wires Material 3 theming (with dynamic color when available)
/// to the go_router shell.
class SniptApp extends StatelessWidget {
  const SniptApp({super.key});

  @override
  Widget build(BuildContext context) {
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
