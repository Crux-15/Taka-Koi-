import 'package:flutter/material.dart';
import '../../utils/app_colors.dart';

/// A premium gradient primary action button with loading state.
class AppButton extends StatelessWidget {
  final String   label;
  final VoidCallback? onPressed;
  final bool     isLoading;
  final bool     outlined;
  final IconData? icon;
  final Color?   color;
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
    this.width,
    this.height = 56,
  });

  @override
  Widget build(BuildContext context) {
    if (outlined) {
      return SizedBox(
        width:  width,
        height: height,
        child: OutlinedButton.icon(
          onPressed: isLoading ? null : onPressed,
          style: color != null ? OutlinedButton.styleFrom(
            foregroundColor: color,
            side: BorderSide(color: color!),
          ) : null,
          icon:   icon != null ? Icon(icon, size: 20) : const SizedBox.shrink(),
          label:  isLoading
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
              : Text(label),
        ),
      );
    }

    return SizedBox(
      width:  width,
      height: height,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: onPressed != null
              ? (color != null
                  ? LinearGradient(colors: [color!, color!])
                  : AppColors.primaryGradient)
              : const LinearGradient(colors: [Color(0xFFBBBBBB), Color(0xFFCCCCCC)]),
          borderRadius: BorderRadius.circular(14),
          boxShadow: onPressed != null
              ? [BoxShadow(color: AppColors.primary.withOpacity(0.35), blurRadius: 16, offset: const Offset(0, 6))]
              : [],
        ),
        child: ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            shadowColor:     Colors.transparent,
            minimumSize:     Size(width ?? double.infinity, height),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
          onPressed: isLoading ? null : onPressed,
          icon: icon != null && !isLoading
              ? Icon(icon, size: 20, color: Colors.white)
              : const SizedBox.shrink(),
          label: isLoading
              ? const SizedBox(
                  width: 22, height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                )
              : Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 16)),
        ),
      ),
    );
  }
}

/// A small pill-shaped status badge.
class StatusBadge extends StatelessWidget {
  final String status; // 'pending' | 'approved' | 'rejected'

  const StatusBadge({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    final Color bg;
    final Color fg;
    final String label;
    switch (status) {
      case 'approved':
        bg = AppColors.approved.withOpacity(0.15); fg = AppColors.approved; label = 'Approved'; break;
      case 'rejected':
        bg = AppColors.rejected.withOpacity(0.15); fg = AppColors.rejected; label = 'Rejected'; break;
      default:
        bg = AppColors.pending.withOpacity(0.15);  fg = AppColors.pending;  label = 'Pending';
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(100)),
      child: Text(label, style: TextStyle(color: fg, fontSize: 11, fontWeight: FontWeight.w600)),
    );
  }
}
