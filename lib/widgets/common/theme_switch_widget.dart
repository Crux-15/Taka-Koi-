import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../controllers/theme_controller.dart';
import '../../utils/app_palette.dart';

/// Round light/dark toggle for app bars: the icon morphs between sun and moon.
class ThemeSwitchWidget extends StatelessWidget {
  final Color? background;
  final Color? foreground;

  const ThemeSwitchWidget({super.key, this.background, this.foreground});

  @override
  Widget build(BuildContext context) {
    final themeCtrl = context.watch<ThemeController>();
    final isDark    = themeCtrl.resolveIsDark(context);
    final p         = context.palette;

    return Tooltip(
      message: isDark ? 'Switch to light mode' : 'Switch to dark mode',
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          themeCtrl.toggleTheme(context);
        },
        child: Container(
          width: 40, height: 40,
          decoration: BoxDecoration(
            color:  background ?? p.surface,
            shape:  BoxShape.circle,
            border: Border.all(color: p.hairline),
          ),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 320),
            transitionBuilder: (child, anim) => RotationTransition(
              turns: Tween(begin: 0.6, end: 1.0).animate(anim),
              child: FadeTransition(opacity: anim, child: child),
            ),
            child: Icon(
              isDark ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
              key:   ValueKey(isDark),
              size:  19,
              color: foreground ?? p.accent,
            ),
          ),
        ),
      ),
    );
  }
}
