import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../utils/app_colors.dart';
import '../ui/ui.dart';

/// The app's main button.
///
/// * default: gold foil in dark mode, ink in light mode (the primary action)
/// * [outlined]: quiet secondary action
/// * [color] / [gradient]: a coloured action (e.g. green "Approve")
class AppButton extends StatelessWidget {
  final String   label;
  final VoidCallback? onPressed;
  final bool     isLoading;
  final bool     outlined;
  final IconData? icon;
  final Color?   color;
  final Gradient? gradient;
  final Color?   textColor;
  final double?  width;
  final double   height;

  const AppButton({
    super.key,
    required this.label,
    this.onPressed,
    this.isLoading = false,
    this.outlined  = false,
    this.icon,
    this.color,
    this.gradient,
    this.textColor,
    this.width,
    this.height = 54,
  });

  bool get _enabled => onPressed != null && !isLoading;

  void _handleTap() {
    HapticFeedback.lightImpact();
    onPressed?.call();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;

    final Color fg;
    final BoxDecoration deco;
    if (outlined) {
      fg = color ?? p.text;
      deco = BoxDecoration(
        color:        Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        border:       Border.all(color: color?.withValues(alpha: 0.55) ?? p.hairline, width: 1.3),
      );
    } else if (onPressed == null) {
      fg = p.textFaint;
      deco = BoxDecoration(color: p.surfaceSunken, borderRadius: BorderRadius.circular(16));
    } else {
      final fill  = gradient ?? (color == null && p.isDark ? AppColors.goldGradient : null);
      final solid = color ?? AppColors.poshObsidian;
      fg = textColor ??
          (color != null || gradient != null
              ? Colors.white
              : (p.isDark ? AppColors.ink : Colors.white));
      deco = BoxDecoration(
        gradient:     fill,
        color:        fill == null ? solid : null,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: (color ?? (p.isDark ? AppColors.goldDeep : AppColors.poshObsidian))
                .withValues(alpha: p.isDark ? 0.22 : 0.16),
            blurRadius: 14,
            offset:     const Offset(0, 5),
          ),
        ],
      );
    }

    final content = isLoading
        ? SizedBox(
            width: 20, height: 20,
            child: CircularProgressIndicator(strokeWidth: 2.4, color: fg),
          )
        : Row(
            mainAxisSize:      MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 19, color: fg),
                const SizedBox(width: 8),
              ],
              Flexible(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: AppType.display, fontSize: 15,
                    fontWeight: FontWeight.w600, letterSpacing: 0.1, color: fg,
                  ),
                ),
              ),
            ],
          );

    return Semantics(
      button:  true,
      enabled: _enabled,
      label:   label,
      child: Pressable(
        onTap:  _enabled ? _handleTap : null,
        haptic: false,
        child: AnimatedContainer(
          duration:   const Duration(milliseconds: 180),
          width:      width ?? double.infinity,
          height:     height,
          alignment:  Alignment.center,
          padding:    const EdgeInsets.symmetric(horizontal: 18),
          decoration: deco,
          child:      content,
        ),
      ),
    );
  }
}

/// A small pill-shaped status badge (kept for older screens).
class StatusBadge extends StatelessWidget {
  final String status; // 'pending' | 'approved' | 'rejected'

  const StatusBadge({super.key, required this.status});

  @override
  Widget build(BuildContext context) => StatusChip.status(status);
}
