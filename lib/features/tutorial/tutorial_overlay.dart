import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

/// Where the tooltip card sits relative to the spotlight hole.
enum TooltipPlacement { above, below }

/// A single step in the coach-mark tour.
class TutorialStep {
  const TutorialStep({
    required this.targetKey,
    required this.title,
    required this.body,
    this.placement = TooltipPlacement.below,
  });

  final GlobalKey targetKey;
  final String title;
  final String body;
  final TooltipPlacement placement;
}

/// Full-screen spotlight overlay that highlights one widget at a time.
///
/// Every tap advances — the underlying UI is never actually interacted with.
/// The caller persists the "shown" state in [onComplete] / [onSkip].
class TutorialOverlay extends StatefulWidget {
  const TutorialOverlay({
    super.key,
    required this.steps,
    required this.onComplete,
    required this.onSkip,
  });

  final List<TutorialStep> steps;
  final VoidCallback onComplete;
  final VoidCallback onSkip;

  @override
  State<TutorialOverlay> createState() => _TutorialOverlayState();
}

class _TutorialOverlayState extends State<TutorialOverlay> {
  int _current = 0;
  Rect? _targetRect;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _measure());
  }

  void _measure() {
    if (!mounted || _current >= widget.steps.length) return;
    final key = widget.steps[_current].targetKey;
    final box = key.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) {
      _advance();
      return;
    }
    final pos = box.localToGlobal(Offset.zero);
    setState(() {
      _targetRect = pos & box.size;
    });
  }

  void _advance() {
    if (_current < widget.steps.length - 1) {
      setState(() {
        _current++;
        _targetRect = null;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) => _measure());
    } else {
      widget.onComplete();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    final screenSize = MediaQuery.sizeOf(context);
    final step = widget.steps[_current];
    final target = _targetRect;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _advance,
      child: SizedBox.expand(
        child: target == null
            ? const SizedBox.shrink()
            : Stack(
                children: [
                  Positioned.fill(
                    child: CustomPaint(
                      painter: _SpotlightPainter(
                        target: target,
                        dimColor: Colors.black.withValues(alpha: 0.72),
                        padding: 6,
                        radius: 12,
                      ),
                    ),
                  ),
                  _tooltip(context, step, target, screenSize, theme),
                ],
              ),
      ),
    );
  }

  Widget _tooltip(
    BuildContext context,
    TutorialStep step,
    Rect target,
    Size screenSize,
    ShadThemeData theme,
  ) {
    final tooltipWidth = (screenSize.width - 32).clamp(260.0, 340.0);

    double? top;
    double? bottom;
    if (step.placement == TooltipPlacement.below) {
      top = target.bottom + 16;
    } else {
      bottom = screenSize.height - target.top + 16;
    }

    double left = target.center.dx - tooltipWidth / 2;
    left = left.clamp(16.0, screenSize.width - tooltipWidth - 16);

    return Positioned(
      top: top,
      bottom: bottom,
      left: left,
      width: tooltipWidth,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: theme.colorScheme.popover,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: theme.colorScheme.border),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(step.title, style: theme.textTheme.p),
                ),
                GestureDetector(
                  onTap: widget.onSkip,
                  child: Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: Text(
                      'Skip',
                      style: theme.textTheme.small.copyWith(
                        color: theme.colorScheme.mutedForeground,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(step.body, style: theme.textTheme.muted),
            const SizedBox(height: 12),
            Row(
              children: [
                Text(
                  '${_current + 1} of ${widget.steps.length}',
                  style: theme.textTheme.small.copyWith(
                    color: theme.colorScheme.mutedForeground,
                  ),
                ),
                const Spacer(),
                ShadButton.raw(
                  variant: ShadButtonVariant.secondary,
                  size: ShadButtonSize.sm,
                  onPressed: _advance,
                  child: Text(
                    _current == widget.steps.length - 1 ? 'Done' : 'Next',
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SpotlightPainter extends CustomPainter {
  _SpotlightPainter({
    required this.target,
    required this.dimColor,
    required this.padding,
    required this.radius,
  });

  final Rect target;
  final Color dimColor;
  final double padding;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final hole = RRect.fromRectAndRadius(
      target.inflate(padding),
      Radius.circular(radius),
    );

    canvas.saveLayer(Offset.zero & size, Paint());
    canvas.drawRect(Offset.zero & size, Paint()..color = dimColor);
    canvas.drawRRect(hole, Paint()..blendMode = BlendMode.clear);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _SpotlightPainter old) =>
      target != old.target || dimColor != old.dimColor;
}
