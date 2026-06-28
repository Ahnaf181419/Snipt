import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

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

  final Widget child;
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
    final theme = ShadTheme.of(context);
    return ShadBadge.secondary(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(LucideIcons.crown, size: 14, color: theme.colorScheme.foreground),
          const SizedBox(width: 4),
          Text(
            'Pro',
            style: theme.textTheme.small.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
