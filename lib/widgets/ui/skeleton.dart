import 'package:flutter/material.dart';
import '../../utils/app_palette.dart';

/// A shimmering placeholder shown while data loads, instead of a spinner or,
/// worse, an empty state that isn't true yet.
class Skeleton extends StatefulWidget {
  final double? width;
  final double height;
  final double radius;

  const Skeleton({super.key, this.width, this.height = 14, this.radius = 8});

  @override
  State<Skeleton> createState() => _SkeletonState();
}

class _SkeletonState extends State<Skeleton> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final base = p.surfaceRaised;
    final shine = p.isDark ? p.surfaceSunken : p.surfaceSunken.withValues(alpha: 0.6);
    return AnimatedBuilder(
      animation: _c,
      builder: (_, __) {
        final t = _c.value * 2 - 0.5;
        return Container(
          width:  widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.radius),
            gradient: LinearGradient(
              begin: Alignment(-1 + t * 2, 0),
              end:   Alignment(t * 2, 0),
              colors: [base, shine, base],
            ),
          ),
        );
      },
    );
  }
}

/// A list of card-shaped skeletons.
class SkeletonList extends StatelessWidget {
  final int count;
  final double itemHeight;
  final EdgeInsetsGeometry padding;

  const SkeletonList({super.key, this.count = 4, this.itemHeight = 76, this.padding = const EdgeInsets.all(20)});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return ListView.separated(
      padding:          padding,
      physics:          const NeverScrollableScrollPhysics(),
      itemCount:        count,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (_, __) => Container(
        height: itemHeight,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color:        p.surface,
          borderRadius: BorderRadius.circular(20),
          border:       Border.all(color: p.hairline),
        ),
        child: const Row(
          children: [
            Skeleton(width: 44, height: 44, radius: 14),
            SizedBox(width: 14),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Skeleton(width: 140, height: 13),
                  SizedBox(height: 8),
                  Skeleton(width: 90, height: 11),
                ],
              ),
            ),
            Skeleton(width: 64, height: 16),
          ],
        ),
      ),
    );
  }
}
