import 'package:flutter/material.dart';

/// Type system: Montserrat for headings and amounts, Work Sans for reading.
/// Both are bundled (assets/fonts), so text looks the same offline.
class AppType {
  AppType._();

  static const String display = 'Montserrat';
  static const String body    = 'WorkSans';

  /// Digits all the same width, so amounts line up and don't jiggle.
  static const List<FontFeature> tabular = [FontFeature.tabularFigures()];

  static TextTheme textTheme(Color text, Color muted) {
    TextStyle d(double size, FontWeight w, double ls, [double? h]) => TextStyle(
          fontFamily: display, fontSize: size, fontWeight: w, letterSpacing: ls,
          height: h, color: text);
    TextStyle b(double size, FontWeight w, {double ls = 0, double h = 1.45, Color? c}) => TextStyle(
          fontFamily: body, fontSize: size, fontWeight: w, letterSpacing: ls,
          height: h, color: c ?? text);
    return TextTheme(
      displayLarge:   d(44, FontWeight.w700, -1.2, 1.1),
      displayMedium:  d(36, FontWeight.w700, -1.0, 1.1),
      displaySmall:   d(30, FontWeight.w700, -0.8, 1.15),
      headlineLarge:  d(28, FontWeight.w700, -0.6, 1.2),
      headlineMedium: d(24, FontWeight.w700, -0.5, 1.2),
      headlineSmall:  d(21, FontWeight.w600, -0.3, 1.25),
      titleLarge:     d(19, FontWeight.w600, -0.2, 1.3),
      titleMedium:    d(16, FontWeight.w600, -0.1, 1.3),
      titleSmall:     b(14.5, FontWeight.w600, h: 1.35),
      bodyLarge:      b(16, FontWeight.w400),
      bodyMedium:     b(14.5, FontWeight.w400),
      bodySmall:      b(12.5, FontWeight.w400, c: muted),
      labelLarge:     b(15, FontWeight.w600, ls: 0.1, h: 1.2),
      labelMedium:    b(13, FontWeight.w500, h: 1.2, c: muted),
      labelSmall:     b(11.5, FontWeight.w600, ls: 0.6, h: 1.2, c: muted),
    );
  }

  /// Amount style: Montserrat with tabular digits.
  static TextStyle money(double size, {FontWeight weight = FontWeight.w700, Color? color}) => TextStyle(
        fontFamily:   display,
        fontSize:     size,
        fontWeight:   weight,
        letterSpacing: size >= 28 ? -1.0 : -0.3,
        height:       1.1,
        color:        color,
        fontFeatures: tabular,
      );

  /// Small caps-style section label ("YOUR BALANCE").
  static TextStyle overline(Color color) => TextStyle(
        fontFamily: body, fontSize: 11.5, fontWeight: FontWeight.w600,
        letterSpacing: 1.1, color: color,
      );
}
