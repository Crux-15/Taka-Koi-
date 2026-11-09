import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../../../utils/app_colors.dart';
import '../../../utils/app_router.dart';
import '../../../widgets/ui/ui.dart';

/// The floating "Add expense" button on Home: the app's main action.
class LogExpenseFab extends StatelessWidget {
  const LogExpenseFab({super.key});

  @override
  Widget build(BuildContext context) {
    final p  = context.palette;
    final fg = p.isDark ? AppColors.ink : Colors.white;
    return Semantics(
      button: true,
      label:  'Add expense',
      child: Pressable(
        onTap: () {
          HapticFeedback.mediumImpact();
          context.push(AppRoutes.logExpense);
        },
        haptic: false,
        child: Container(
          height:  54,
          padding: const EdgeInsets.symmetric(horizontal: 22),
          decoration: BoxDecoration(
            gradient:     p.isDark ? AppColors.goldGradient : null,
            color:        p.isDark ? null : AppColors.poshObsidian,
            borderRadius: BorderRadius.circular(100),
            boxShadow: [
              BoxShadow(
                color: (p.isDark ? AppColors.goldDeep : Colors.black).withValues(alpha: p.isDark ? 0.40 : 0.28),
                blurRadius: 22,
                offset:     const Offset(0, 10),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.add_rounded, size: 22, color: fg),
              const SizedBox(width: 8),
              Text('Add expense',
                  style: TextStyle(fontFamily: AppType.display, fontSize: 15, fontWeight: FontWeight.w600, color: fg)),
            ],
          ),
        ),
      ),
    );
  }
}
