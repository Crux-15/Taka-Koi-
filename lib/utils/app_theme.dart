import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'app_colors.dart';
import 'app_palette.dart';
import 'app_typography.dart';

/// Material 3 themes for light and dark mode, both built from [AppPalette]
/// so every standard widget (buttons, fields, sheets, dialogs, tabs, ...)
/// matches the custom components.
class AppTheme {
  AppTheme._();

  static ThemeData get light => _build(AppPalette.light);
  static ThemeData get dark  => _build(AppPalette.dark);

  static const double radiusS  = 12;
  static const double radiusM  = 16;
  static const double radiusL  = 20;
  static const double radiusXL = 28;

  // Kept for older call sites.
  static const double elevationS = 2.0;
  static const double elevationM = 6.0;
  static const double elevationL = 12.0;

  static ThemeData _build(AppPalette p) {
    final isDark = p.isDark;
    final text   = AppType.textTheme(p.text, p.textMuted);

    // Primary action: gold foil on dark, ink on light.
    final primaryBg = isDark ? AppColors.primary : AppColors.poshObsidian;
    final primaryFg = isDark ? AppColors.ink : Colors.white;

    final scheme = ColorScheme(
      brightness:              isDark ? Brightness.dark : Brightness.light,
      primary:                 p.accent,
      onPrimary:               p.onAccent,
      primaryContainer:        p.soft(p.accent),
      onPrimaryContainer:      p.accent,
      secondary:               AppColors.secondary,
      onSecondary:             Colors.white,
      secondaryContainer:      p.soft(AppColors.secondary),
      onSecondaryContainer:    p.text,
      tertiary:                p.info,
      onTertiary:              Colors.white,
      tertiaryContainer:       p.soft(p.info),
      onTertiaryContainer:     p.text,
      error:                   p.negative,
      onError:                 Colors.white,
      errorContainer:          p.soft(p.negative),
      onErrorContainer:        p.negative,
      surface:                 p.surface,
      onSurface:               p.text,
      surfaceContainerLowest:  p.background,
      surfaceContainerLow:     p.surface,
      surfaceContainer:        p.surface,
      surfaceContainerHigh:    p.surfaceRaised,
      surfaceContainerHighest: p.surfaceRaised,
      onSurfaceVariant:        p.textMuted,
      outline:                 p.hairline,
      outlineVariant:          p.hairline,
      shadow:                  Colors.black,
      scrim:                   Colors.black,
      inverseSurface:          isDark ? AppColors.surfaceLight : AppColors.poshObsidian,
      onInverseSurface:        isDark ? AppColors.poshObsidian : AppColors.onSurfaceDark,
      inversePrimary:          isDark ? AppColors.poshGold : AppColors.primary,
      surfaceTint:             Colors.transparent,
    );

    final rounded = RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusM));
    const buttonText = TextStyle(fontFamily: AppType.display, fontSize: 15, fontWeight: FontWeight.w600, letterSpacing: 0.1);

    // Filled fields: the label floats inside the rounded box, and focus shows
    // as an accent edge along the bottom.
    UnderlineInputBorder field(Color c, [double w = 0]) => UnderlineInputBorder(
          borderRadius: BorderRadius.circular(radiusM),
          borderSide: w == 0 ? BorderSide.none : BorderSide(color: c, width: w),
        );

    return ThemeData(
      useMaterial3:            true,
      brightness:              scheme.brightness,
      colorScheme:             scheme,
      fontFamily:              AppType.body,
      textTheme:               text,
      scaffoldBackgroundColor: p.background,
      canvasColor:             p.background,
      dividerColor:            p.hairline,
      splashFactory:           InkSparkle.splashFactory,
      extensions:              [p],
      visualDensity:           VisualDensity.standard,

      pageTransitionsTheme: const PageTransitionsTheme(builders: {
        TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
        TargetPlatform.iOS:     CupertinoPageTransitionsBuilder(),
      }),

      appBarTheme: AppBarTheme(
        backgroundColor:        p.background,
        foregroundColor:        p.text,
        surfaceTintColor:       Colors.transparent,
        elevation:              0,
        scrolledUnderElevation: 0,
        centerTitle:            false,
        titleSpacing:           20,
        titleTextStyle:         text.titleLarge?.copyWith(fontWeight: FontWeight.w700),
        iconTheme:              IconThemeData(color: p.text, size: 22),
        systemOverlayStyle:     isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
      ),

      cardTheme: CardThemeData(
        color:       p.surface,
        elevation:   0,
        margin:      EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusL),
          side: BorderSide(color: p.hairline),
        ),
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryBg,
          foregroundColor: primaryFg,
          disabledBackgroundColor: p.surfaceSunken,
          disabledForegroundColor: p.textFaint,
          elevation:       0,
          minimumSize:     const Size(64, 54),
          shape:           rounded,
          textStyle:       buttonText,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: primaryBg,
          foregroundColor: primaryFg,
          disabledBackgroundColor: p.surfaceSunken,
          disabledForegroundColor: p.textFaint,
          minimumSize:     const Size(64, 54),
          shape:           rounded,
          textStyle:       buttonText,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: p.text,
          side:            BorderSide(color: p.hairline, width: 1.2),
          minimumSize:     const Size(64, 54),
          shape:           rounded,
          textStyle:       buttonText,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: p.accent,
          shape:           RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusS)),
          textStyle:       buttonText.copyWith(fontSize: 14),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(foregroundColor: p.text),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: primaryBg,
        foregroundColor: primaryFg,
        elevation:       0,
        highlightElevation: 0,
        shape:           RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusL)),
        extendedTextStyle: buttonText,
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled:             true,
        fillColor:          p.surfaceRaised,
        contentPadding:     const EdgeInsets.fromLTRB(18, 14, 18, 14),
        border:             field(p.hairline),
        enabledBorder:      field(p.hairline),
        disabledBorder:     field(p.hairline),
        focusedBorder:      field(p.accent, 2),
        errorBorder:        field(p.negative, 1.5),
        focusedErrorBorder: field(p.negative, 2),
        hintStyle:          text.bodyMedium?.copyWith(color: p.textFaint),
        labelStyle:         text.bodyMedium?.copyWith(color: p.textMuted),
        floatingLabelStyle: WidgetStateTextStyle.resolveWith((s) => (text.bodySmall ?? const TextStyle()).copyWith(
              color: s.contains(WidgetState.error)
                  ? p.negative
                  : s.contains(WidgetState.focused) ? p.accent : p.textMuted,
              fontWeight: FontWeight.w600,
            )),
        prefixIconColor:    p.textMuted,
        suffixIconColor:    p.textMuted,
        errorStyle:         text.bodySmall?.copyWith(color: p.negative),
      ),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor:    p.accent,
        selectionColor: p.soft(p.accent),
        selectionHandleColor: p.accent,
      ),

      chipTheme: ChipThemeData(
        backgroundColor: p.surfaceRaised,
        selectedColor:   p.soft(p.accent),
        side:            BorderSide(color: p.hairline),
        shape:           const StadiumBorder(),
        labelStyle:      text.labelMedium?.copyWith(color: p.text),
        padding:         const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      ),

      tabBarTheme: TabBarThemeData(
        labelColor:           p.text,
        unselectedLabelColor: p.textMuted,
        dividerColor:         Colors.transparent,
        indicatorSize:        TabBarIndicatorSize.tab,
        indicator: BoxDecoration(
          color:        isDark ? p.surfaceSunken : p.surface,
          borderRadius: BorderRadius.circular(12),
          boxShadow:    isDark ? null : p.cardShadow,
        ),
        splashFactory:        NoSplash.splashFactory,
        overlayColor:         const WidgetStatePropertyAll(Colors.transparent),
        labelStyle:           const TextStyle(fontFamily: AppType.display, fontSize: 13.5, fontWeight: FontWeight.w600),
        unselectedLabelStyle: const TextStyle(fontFamily: AppType.display, fontSize: 13.5, fontWeight: FontWeight.w500),
      ),

      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor:      p.surface,
        surfaceTintColor:     Colors.transparent,
        modalBackgroundColor: p.surface,
        showDragHandle:       true,
        dragHandleColor:      p.textFaint.withValues(alpha: 0.5),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(radiusXL)),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor:  p.surface,
        surfaceTintColor: Colors.transparent,
        shape:            RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        titleTextStyle:   text.titleLarge?.copyWith(fontWeight: FontWeight.w700),
        contentTextStyle: text.bodyMedium?.copyWith(color: p.textMuted),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior:         SnackBarBehavior.floating,
        backgroundColor:  isDark ? const Color(0xFF2A261F) : AppColors.poshObsidian,
        contentTextStyle: text.bodyMedium?.copyWith(color: AppColors.onSurfaceDark, fontWeight: FontWeight.w500),
        actionTextColor:  AppColors.primary,
        elevation:        0,
        insetPadding:     const EdgeInsets.fromLTRB(16, 0, 16, 16),
        shape:            RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color:            p.surface,
        surfaceTintColor: Colors.transparent,
        shape:            RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusM), side: BorderSide(color: p.hairline)),
        textStyle:        text.bodyMedium,
      ),

      listTileTheme: ListTileThemeData(
        iconColor:          p.textMuted,
        textColor:          p.text,
        titleTextStyle:     text.titleSmall,
        subtitleTextStyle:  text.bodySmall,
        contentPadding:     const EdgeInsets.symmetric(horizontal: 16),
        shape:              RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusM)),
      ),
      dividerTheme:   DividerThemeData(color: p.hairline, thickness: 1, space: 1),
      iconTheme:      IconThemeData(color: p.textMuted, size: 22),
      badgeTheme:     BadgeThemeData(backgroundColor: p.negative, textColor: Colors.white),

      progressIndicatorTheme: ProgressIndicatorThemeData(
        color:              p.accent,
        linearTrackColor:   p.surfaceSunken,
        circularTrackColor: Colors.transparent,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.selected) ? p.onAccent : p.textMuted),
        trackColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.selected) ? p.accent : p.surfaceSunken),
        trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.selected) ? p.accent : Colors.transparent),
        checkColor: WidgetStatePropertyAll(p.onAccent),
        side:       BorderSide(color: p.textFaint, width: 1.5),
        shape:      RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      ),
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.selected) ? p.accent : p.textFaint),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: SegmentedButton.styleFrom(
          backgroundColor:         p.surfaceRaised,
          selectedBackgroundColor: isDark ? p.surfaceSunken : p.surface,
          selectedForegroundColor: p.text,
          foregroundColor:         p.textMuted,
          side:                    BorderSide(color: p.hairline),
          textStyle:               const TextStyle(fontFamily: AppType.display, fontWeight: FontWeight.w600, fontSize: 13.5),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor:  p.surface,
        surfaceTintColor: Colors.transparent,
        indicatorColor:   p.soft(p.accent),
        elevation:        0,
        labelTextStyle: WidgetStateProperty.resolveWith((s) => TextStyle(
              fontFamily: AppType.body, fontSize: 12,
              fontWeight: s.contains(WidgetState.selected) ? FontWeight.w600 : FontWeight.w500,
              color: s.contains(WidgetState.selected) ? p.text : p.textMuted,
            )),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(color: AppColors.poshObsidian, borderRadius: BorderRadius.circular(10)),
        textStyle:  text.bodySmall?.copyWith(color: AppColors.onSurfaceDark),
      ),
    );
  }
}
