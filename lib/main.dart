import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';

void main() {
  // Ensure bindings are ready before any plugin calls.
  WidgetsFlutterBinding.ensureInitialized();

  // Catch framework-level errors (widget build failures, etc.) that would
  // otherwise show the default red error screen. In debug mode Flutter still
  // prints the full stack; in release these land silently in the zone.
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    // In a production app you would forward to crash reporting here.
    debugPrint('FlutterError: ${details.exception}');
  };

  // Catch errors that escape the framework (async errors, native plugin
  // failures, etc.). runZonedGuarded is the outermost safety net.
  runZonedGuarded(
    () => runApp(const ProviderScope(child: SniptApp())),
    (error, stack) {
      debugPrint('Zone error: $error\n$stack');
    },
  );
}
