import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../utils/app_palette.dart';
import '../../utils/app_typography.dart';

/// Shrinks a touch while pressed, for a tactile feel on cards and tiles.
class Pressable extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final double scale;
  final bool haptic;

  const Pressable({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.scale  = 0.98,
    this.haptic = true,
  });

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _down = false;

  void _set(bool v) {
    if (widget.onTap == null && widget.onLongPress == null) return;
    if (_down != v) setState(() => _down = v);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior:    HitTestBehavior.opaque,
      onTapDown:   (_) => _set(true),
      onTapUp:     (_) => _set(false),
      onTapCancel: () => _set(false),
      onTap: widget.onTap == null
          ? null
          : () {
              if (widget.haptic) HapticFeedback.selectionClick();
              widget.onTap!();
            },
      onLongPress: widget.onLongPress,
      child: AnimatedScale(
        scale:    _down ? widget.scale : 1,
        duration: const Duration(milliseconds: 120),
        curve:    Curves.easeOut,
        child:    widget.child,
      ),
    );
  }
}

/// The standard card: surface colour, hairline border, soft shadow in light
/// mode, optional tap.
class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final Color? color;
  final Gradient? gradient;
  final double radius;
  final Color? borderColor;
  final bool shadow;

  const AppCard({
    super.key,
    required this.child,
    this.padding     = const EdgeInsets.all(16),
    this.onTap,
    this.color,
    this.gradient,
    this.radius      = 20,
    this.borderColor,
    this.shadow      = true,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final card = DecoratedBox(
      decoration: BoxDecoration(
        color:        gradient == null ? (color ?? p.surface) : null,
        gradient:     gradient,
        borderRadius: BorderRadius.circular(radius),
        border:       Border.all(color: borderColor ?? p.hairline),
        boxShadow:    shadow ? p.cardShadow : null,
      ),
      child: Padding(padding: padding, child: child),
    );
    if (onTap == null) return card;
    return Pressable(onTap: onTap, child: card);
  }
}

/// A rounded-square icon on a tinted background (list leading, quick actions).
class IconTile extends StatelessWidget {
  final IconData icon;
  final Color? color;
  final double size;
  final double radius;

  const IconTile(this.icon, {super.key, this.color, this.size = 44, this.radius = 14});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final c = color ?? p.accent;
    return Container(
      width:  size,
      height: size,
      decoration: BoxDecoration(
        color:        p.soft(c),
        borderRadius: BorderRadius.circular(radius),
      ),
      child: Icon(icon, color: c, size: size * 0.5),
    );
  }
}

/// "Recent expenses ......... See all"
class SectionHeader extends StatelessWidget {
  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;
  final Widget? trailing;
  final EdgeInsetsGeometry padding;

  const SectionHeader(
    this.title, {
    super.key,
    this.actionLabel,
    this.onAction,
    this.trailing,
    this.padding = const EdgeInsets.fromLTRB(4, 0, 4, 12),
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Padding(
      padding: padding,
      child: Row(
        children: [
          Expanded(
            child: Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
          ),
          if (trailing != null) trailing!,
          if (actionLabel != null)
            GestureDetector(
              onTap: onAction,
              child: Text(actionLabel!,
                  style: TextStyle(
                    fontFamily: AppType.body, fontSize: 13.5,
                    fontWeight: FontWeight.w600, color: p.accent,
                  )),
            ),
        ],
      ),
    );
  }
}

enum ChipTone { neutral, accent, positive, negative, pending, info }

/// Small rounded status label ("Pending", "Settled", "Admin").
class StatusChip extends StatelessWidget {
  final String label;
  final ChipTone tone;
  final IconData? icon;
  final bool dense;

  const StatusChip(this.label, {super.key, this.tone = ChipTone.neutral, this.icon, this.dense = false});

  /// Chip for an expense/payment status string.
  factory StatusChip.status(String status, {Key? key, bool dense = false}) {
    switch (status) {
      case 'approved':
        return StatusChip('Approved', key: key, tone: ChipTone.positive, icon: Icons.check_rounded, dense: dense);
      case 'rejected':
        return StatusChip('Rejected', key: key, tone: ChipTone.negative, icon: Icons.close_rounded, dense: dense);
      case 'settled':
        return StatusChip('Settled', key: key, tone: ChipTone.positive, icon: Icons.done_all_rounded, dense: dense);
      default:
        return StatusChip('Pending', key: key, tone: ChipTone.pending, icon: Icons.schedule_rounded, dense: dense);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final c = switch (tone) {
      ChipTone.neutral  => p.textMuted,
      ChipTone.accent   => p.accent,
      ChipTone.positive => p.positive,
      ChipTone.negative => p.negative,
      ChipTone.pending  => p.pending,
      ChipTone.info     => p.info,
    };
    return Container(
      padding: EdgeInsets.symmetric(horizontal: dense ? 7 : 9, vertical: dense ? 2.5 : 4),
      decoration: BoxDecoration(
        color:        tone == ChipTone.neutral ? p.surfaceRaised : p.soft(c),
        borderRadius: BorderRadius.circular(100),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: dense ? 11 : 13, color: c),
            const SizedBox(width: 4),
          ],
          Flexible(
            child: Text(label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: AppType.body, fontSize: dense ? 11 : 12,
                  fontWeight: FontWeight.w600, color: c, height: 1.2,
                )),
          ),
        ],
      ),
    );
  }
}

/// A soft banner with an icon (tips, warnings, offline notes).
class InfoBanner extends StatelessWidget {
  final String text;
  final IconData icon;
  final ChipTone tone;

  const InfoBanner(this.text, {super.key, this.icon = Icons.info_outline_rounded, this.tone = ChipTone.info});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final c = switch (tone) {
      ChipTone.positive => p.positive,
      ChipTone.negative => p.negative,
      ChipTone.pending  => p.pending,
      ChipTone.accent   => p.accent,
      _                 => p.info,
    };
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color:        p.soft(c),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: c, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: p.text, height: 1.45)),
          ),
        ],
      ),
    );
  }
}
