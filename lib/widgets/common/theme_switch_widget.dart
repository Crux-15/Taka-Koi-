import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../controllers/theme_controller.dart';
import '../../utils/app_colors.dart';

/// An animated sun/moon theme toggle switch shown in app bars.
class ThemeSwitchWidget extends StatelessWidget {
  const ThemeSwitchWidget({super.key});

  static const _animDuration = Duration(milliseconds: 300);

  @override
  Widget build(BuildContext context) {
    final themeCtrl  = context.watch<ThemeController>();
    final isDark     = themeCtrl.resolveIsDark(context);

    return GestureDetector(
      onTap: () => themeCtrl.toggleTheme(context),
      child: AnimatedContainer(
        duration: _animDuration,
        width:    52,
        height:   28,
        padding:  const EdgeInsets.all(3),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          gradient: isDark ? AppColors.primaryGradient : null,
          color:    isDark ? null : const Color(0xFFE0E0E0),
        ),
        child: AnimatedAlign(
          duration: _animDuration,
          curve:    Curves.easeInOut,
          alignment: isDark ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            width:  22,
            height: 22,
            decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
            child: Icon(
              isDark ? Icons.nightlight_round : Icons.wb_sunny_rounded,
              size:  13,
              color: isDark ? AppColors.primary : AppColors.warning,
            ),
          ),
        ),
      ),
    );
  }
}


