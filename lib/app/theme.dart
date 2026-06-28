import 'package:flutter/widgets.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

/// shadcn/ui theming for snipt.
///
/// Uses the shadcn zinc neutral palette (the default shadcn look). Both light
/// and dark are generated from the same scheme so the app stays coherent.
/// Dynamic color (Android 12+ wallpaper palette) is intentionally dropped in
/// favour of the consistent shadcn aesthetic.
class AppTheme {
  const AppTheme._();

  static ShadThemeData light() => ShadThemeData(
        colorScheme: const ShadZincColorScheme.light(),
        brightness: Brightness.light,
        radius: const BorderRadius.all(Radius.circular(8)),
      );

  static ShadThemeData dark() => ShadThemeData(
        colorScheme: const ShadZincColorScheme.dark(),
        brightness: Brightness.dark,
        radius: const BorderRadius.all(Radius.circular(8)),
      );
}
