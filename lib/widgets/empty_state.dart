import 'package:flutter/material.dart';

/// A premium empty-state widget with a large icon, title, and subtitle.
/// Uses the color scheme to stay coherent in both light and dark mode.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.action,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: scheme.primaryContainer.withValues(alpha: 0.7),
              ),
              child: Icon(icon, size: 40, color: scheme.onPrimaryContainer),
            ),
            const SizedBox(height: 24),
            Text(
              title,
              style: text.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: scheme.onSurface,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
            if (action != null) ...[const SizedBox(height: 24), action!],
          ],
        ),
      ),
    );
  }
}
