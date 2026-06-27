import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/billing/billing_providers.dart';

/// Wraps a Pro-only widget. When the current user is not Pro, shows the
/// [locked] child instead (a friendly upgrade prompt) and the [child] is
/// not built. When the user is Pro, [child] is shown directly.
///
/// Use this for in-line gating (e.g. an "Export" button) where you want
/// to keep the layout stable and just swap the contents.
class ProGate extends ConsumerWidget {
  const ProGate({
    super.key,
    required this.child,
    this.locked,
  });

  /// The Pro feature. Built only when the user owns Pro.
  final Widget child;

  /// What to render when the user does not own Pro. Defaults to a compact
  /// "Pro" badge that opens the Settings screen. The screen-level upgrade
  /// flow lives there; this widget never launches a purchase itself.
  final Widget? locked;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isPro = ref.watch(isProProvider);
    if (isPro) return child;
    return locked ?? const _ProBadge();
  }
}

class _ProBadge extends StatelessWidget {
  const _ProBadge();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: scheme.primaryContainer,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.workspace_premium, size: 14, color: scheme.onPrimaryContainer),
          const SizedBox(width: 4),
          Text(
            'Pro',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: scheme.onPrimaryContainer,
                  fontWeight: FontWeight.w600,
                ),
          ),
        ],
      ),
    );
  }
}
