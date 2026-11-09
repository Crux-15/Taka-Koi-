import 'package:flutter/material.dart';
import '../../../utils/app_colors.dart';
import '../../../widgets/common/theme_switch_widget.dart';
import '../../../widgets/ui/ui.dart';

/// Brand header for the sign-in screens: the obsidian panel with a soft gold
/// glow, the app's logo, and a title.
class AuthHero extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool showBack;
  final double heightFactor;

  const AuthHero({
    super.key,
    required this.title,
    required this.subtitle,
    this.showBack = false,
    this.heightFactor = 0.36,
  });

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final top  = MediaQuery.paddingOf(context).top;
    return Container(
      height: (size.height * heightFactor).clamp(260.0, 360.0) + top,
      decoration: const BoxDecoration(
        gradient: AppColors.heroGradient,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(36)),
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(36)),
        child: Stack(
          children: [
            Positioned(
              top: -120, left: -60, right: -60,
              child: Container(
                height: 320,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(colors: [Color(0x38E2B044), Color(0x00E2B044)]),
                ),
              ),
            ),
            SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 16, 0),
                child: Row(
                  children: [
                    if (showBack)
                      IconButton(
                        tooltip:   'Back',
                        onPressed: () => Navigator.of(context).maybePop(),
                        icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                      ),
                    const Spacer(),
                    const ThemeSwitchWidget(
                      background: Color(0x1AFFFFFF),
                      foreground: AppColors.primary,
                    ),
                  ],
                ),
              ),
            ),
            Positioned.fill(
              top: top + 36,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      gradient: AppColors.goldGradient,
                      borderRadius: BorderRadius.circular(26),
                      boxShadow: [
                        BoxShadow(color: AppColors.goldDeep.withValues(alpha: 0.35), blurRadius: 24, offset: const Offset(0, 10)),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(23),
                      child: Image.asset('assets/images/taka_koi_logo.jpg', width: 76, height: 76, fit: BoxFit.cover),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(title,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontFamily: AppType.display, fontSize: 27, fontWeight: FontWeight.w700,
                        letterSpacing: -0.6, color: Color(0xFFF7F1E3),
                      )),
                  const SizedBox(height: 6),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Text(subtitle,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontFamily: AppType.body, fontSize: 14.5, height: 1.4, color: Color(0xFFB5AC97))),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
