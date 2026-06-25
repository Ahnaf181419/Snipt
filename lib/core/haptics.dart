import 'package:flutter/services.dart';

/// Centralized haptic feedback helpers. Using named methods instead of raw
/// HapticFeedback calls keeps intensity consistent across the app.
class Haptics {
  const Haptics._();

  /// Light tap feedback for button presses, icon taps, toggles.
  static Future<void> light() => HapticFeedback.lightImpact();

  /// Medium impact for swipes, drag-to-dismiss, bigger actions.
  static Future<void> medium() => HapticFeedback.mediumImpact();

  /// Heavy impact for destructive confirmations (rarely used).
  static Future<void> heavy() => HapticFeedback.heavyImpact();

  /// Selection tick for scrolling through lists or segmented controls.
  static Future<void> selection() => HapticFeedback.selectionClick();
}
