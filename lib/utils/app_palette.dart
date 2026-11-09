import 'package:flutter/material.dart';
import 'app_colors.dart';

/// The colours a screen actually needs, resolved for the current light/dark
/// mode. Use `context.palette` anywhere below MaterialApp.
@immutable
class AppPalette extends ThemeExtension<AppPalette> {
  final bool  isDark;
  final Color background;
  final Color surface;        // cards
  final Color surfaceRaised;  // inputs, chips, nested cards
  final Color surfaceSunken;  // tracks, pressed states
  final Color hairline;
  final Color text;
  final Color textMuted;
  final Color textFaint;
  final Color accent;         // gold that reads on this background
  final Color onAccent;
  final Color positive;       // owed to you / approved
  final Color negative;       // you owe / rejected
  final Color pending;
  final Color info;
  final List<BoxShadow> cardShadow;
  final List<BoxShadow> floatingShadow;

  const AppPalette({
    required this.isDark,
    required this.background,
    required this.surface,
    required this.surfaceRaised,
    required this.surfaceSunken,
    required this.hairline,
    required this.text,
    required this.textMuted,
    required this.textFaint,
    required this.accent,
    required this.onAccent,
    required this.positive,
    required this.negative,
    required this.pending,
    required this.info,
    required this.cardShadow,
    required this.floatingShadow,
  });

  static const dark = AppPalette(
    isDark:        true,
    background:    AppColors.backgroundDark,
    surface:       AppColors.surfaceDark,
    surfaceRaised: AppColors.surfaceVariantDark,
    surfaceSunken: AppColors.surfaceSunkenDark,
    hairline:      AppColors.outlineDark,
    text:          AppColors.onSurfaceDark,
    textMuted:     AppColors.onSurfaceVariantDark,
    textFaint:     AppColors.faintDark,
    accent:        AppColors.primary,
    onAccent:      AppColors.ink,
    positive:      Color(0xFF2CC793),
    negative:      Color(0xFFFF7176),
    pending:       Color(0xFFF4B54F),
    info:          AppColors.info,
    cardShadow:    [],
    floatingShadow: [
      BoxShadow(color: Color(0x99000000), blurRadius: 30, offset: Offset(0, 12)),
    ],
  );

  static const light = AppPalette(
    isDark:        false,
    background:    AppColors.backgroundLight,
    surface:       AppColors.surfaceLight,
    surfaceRaised: AppColors.surfaceVariantLight,
    surfaceSunken: AppColors.surfaceSunkenLight,
    hairline:      AppColors.outlineLight,
    text:          AppColors.onSurfaceLight,
    textMuted:     AppColors.onSurfaceVariantLight,
    textFaint:     AppColors.faintLight,
    accent:        AppColors.poshGold,
    onAccent:      Colors.white,
    positive:      AppColors.successTextLight,
    negative:      AppColors.errorTextLight,
    pending:       AppColors.warningTextLight,
    info:          Color(0xFF2F7FCB),
    cardShadow: [
      BoxShadow(color: Color(0x0A2A2010), blurRadius: 18, offset: Offset(0, 6)),
      BoxShadow(color: Color(0x05000000), blurRadius: 2, offset: Offset(0, 1)),
    ],
    floatingShadow: [
      BoxShadow(color: Color(0x1F2A2010), blurRadius: 30, offset: Offset(0, 12)),
    ],
  );

  /// Tinted background for a coloured badge or banner.
  Color soft(Color c) => c.withValues(alpha: isDark ? 0.16 : 0.10);

  @override
  AppPalette copyWith() => this;

  @override
  AppPalette lerp(ThemeExtension<AppPalette>? other, double t) {
    if (other is! AppPalette) return this;
    Color l(Color a, Color b) => Color.lerp(a, b, t)!;
    return AppPalette(
      isDark:         t < 0.5 ? isDark : other.isDark,
      background:     l(background, other.background),
      surface:        l(surface, other.surface),
      surfaceRaised:  l(surfaceRaised, other.surfaceRaised),
      surfaceSunken:  l(surfaceSunken, other.surfaceSunken),
      hairline:       l(hairline, other.hairline),
      text:           l(text, other.text),
      textMuted:      l(textMuted, other.textMuted),
      textFaint:      l(textFaint, other.textFaint),
      accent:         l(accent, other.accent),
      onAccent:       l(onAccent, other.onAccent),
      positive:       l(positive, other.positive),
      negative:       l(negative, other.negative),
      pending:        l(pending, other.pending),
      info:           l(info, other.info),
      cardShadow:     t < 0.5 ? cardShadow : other.cardShadow,
      floatingShadow: t < 0.5 ? floatingShadow : other.floatingShadow,
    );
  }
}

extension PaletteContext on BuildContext {
  AppPalette get palette => Theme.of(this).extension<AppPalette>() ?? AppPalette.dark;
}
