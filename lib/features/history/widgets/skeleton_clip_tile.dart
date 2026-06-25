import 'package:flutter/material.dart';

/// A shimmer skeleton placeholder matching the ClipTile layout shape.
/// Shown while the database stream is loading its first batch.
class SkeletonClipTile extends StatefulWidget {
  const SkeletonClipTile({super.key});

  @override
  State<SkeletonClipTile> createState() => _SkeletonClipTileState();
}

class _SkeletonClipTileState extends State<SkeletonClipTile>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final baseColor = scheme.surfaceContainerHigh;
    final highlightColor = scheme.surfaceContainerHighest;

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Icon placeholder
            _ShimmerBox(
              controller: _controller,
              baseColor: baseColor,
              highlightColor: highlightColor,
              width: 20,
              height: 20,
              radius: 4,
            ),
            const SizedBox(width: 10),
            // Text lines + metadata
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _ShimmerBox(
                    controller: _controller,
                    baseColor: baseColor,
                    highlightColor: highlightColor,
                    width: double.infinity,
                    height: 14,
                    radius: 4,
                  ),
                  const SizedBox(height: 8),
                  _ShimmerBox(
                    controller: _controller,
                    baseColor: baseColor,
                    highlightColor: highlightColor,
                    width: 180,
                    height: 14,
                    radius: 4,
                  ),
                  const SizedBox(height: 10),
                  _ShimmerBox(
                    controller: _controller,
                    baseColor: baseColor,
                    highlightColor: highlightColor,
                    width: 60,
                    height: 10,
                    radius: 4,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 28),
          ],
        ),
      ),
    );
  }
}

class _ShimmerBox extends StatelessWidget {
  const _ShimmerBox({
    required this.controller,
    required this.baseColor,
    required this.highlightColor,
    required this.width,
    required this.height,
    required this.radius,
  });

  final AnimationController controller;
  final Color baseColor;
  final Color highlightColor;
  final double width;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        return Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(radius),
            color: Color.lerp(
              baseColor,
              highlightColor,
              controller.value,
            ),
          ),
        );
      },
    );
  }
}

/// Renders [count] skeleton tiles to fill the loading viewport.
class SkeletonClipList extends StatelessWidget {
  const SkeletonClipList({super.key, this.count = 6});

  final int count;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 96),
      physics: const NeverScrollableScrollPhysics(),
      itemCount: count,
      itemBuilder: (_, _) => const SkeletonClipTile(),
    );
  }
}
