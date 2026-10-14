import 'package:flutter/material.dart';
import 'app_colors.dart';

/// Builds Material 3 ThemeData for both light and dark modes.
/// Taka Koi! brand: yellow primary, warm cream light, near-black dark.
class AppTheme {
  AppTheme._();

  static const String _fontFamily = 'Poppins';

  // ── onPrimary is BLACK for both themes ────────────────────────────────────
  // Yellow (#FFD700) is a light colour — white text on yellow is illegible.
  // All buttons/FABs with yellow background use black foreground text/icons.
  static const Color _onPrimary = Color(0xFF1A1A1A);

  static TextTheme _buildTextTheme(Color onSurface, Color onSurfaceVariant) {
    return TextTheme(
      displayLarge:  TextStyle(fontFamily: _fontFamily, fontSize: 57, fontWeight: FontWeight.w700, color: onSurface, letterSpacing: -0.5),
      displayMedium: TextStyle(fontFamily: _fontFamily, fontSize: 45, fontWeight: FontWeight.w700, color: onSurface),
      displaySmall:  TextStyle(fontFamily: _fontFamily, fontSize: 36, fontWeight: FontWeight.w700, color: onSurface),
      headlineLarge: TextStyle(fontFamily: _fontFamily, fontSize: 32, fontWeight: FontWeight.w700, color: onSurface),
      headlineMedium:TextStyle(fontFamily: _fontFamily, fontSize: 28, fontWeight: FontWeight.w600, color: onSurface),
      headlineSmall: TextStyle(fontFamily: _fontFamily, fontSize: 24, fontWeight: FontWeight.w600, color: onSurface),
      titleLarge:    TextStyle(fontFamily: _fontFamily, fontSize: 22, fontWeight: FontWeight.w600, color: onSurface),
      titleMedium:   TextStyle(fontFamily: _fontFamily, fontSize: 16, fontWeight: FontWeight.w600, color: onSurface, letterSpacing: 0.15),
      titleSmall:    TextStyle(fontFamily: _fontFamily, fontSize: 14, fontWeight: FontWeight.w500, color: onSurface, letterSpacing: 0.1),
      bodyLarge:     TextStyle(fontFamily: _fontFamily, fontSize: 16, fontWeight: FontWeight.w400, color: onSurface),
      bodyMedium:    TextStyle(fontFamily: _fontFamily, fontSize: 14, fontWeight: FontWeight.w400, color: onSurface),
      bodySmall:     TextStyle(fontFamily: _fontFamily, fontSize: 12, fontWeight: FontWeight.w400, color: onSurfaceVariant),
      labelLarge:    TextStyle(fontFamily: _fontFamily, fontSize: 14, fontWeight: FontWeight.w600, color: onSurface, letterSpacing: 0.1),
      labelMedium:   TextStyle(fontFamily: _fontFamily, fontSize: 12, fontWeight: FontWeight.w500, color: onSurfaceVariant),
      labelSmall:    TextStyle(fontFamily: _fontFamily, fontSize: 11, fontWeight: FontWeight.w500, color: onSurfaceVariant, letterSpacing: 0.5),
    );
  }

  // ── Light Theme ───────────────────────────────────────────────────────────
  static ThemeData get light {
    final scheme = ColorScheme(
      brightness:          Brightness.light,
      primary:             AppColors.poshGold,               // Regal gold: warm, high-contrast, eye-friendly
      onPrimary:           Colors.white,                     // Crisp white on buttons
      primaryContainer:    AppColors.surfaceVariantLight,
      onPrimaryContainer:  AppColors.poshObsidian,
      secondary:           AppColors.secondary,
      onSecondary:         Colors.white,
      secondaryContainer:  const Color(0xFFFFDCBD),          // Light orange
      onSecondaryContainer:const Color(0xFF5C2000),
      tertiary:            AppColors.tertiary,
      onTertiary:          Colors.white,
      tertiaryContainer:   const Color(0xFFB8F0F8),          // Light cyan
      onTertiaryContainer: const Color(0xFF00363E),
      error:               AppColors.error,
      onError:             Colors.white,
      errorContainer:      const Color(0xFFFFDAD6),
      onErrorContainer:    const Color(0xFF93000A),
      surface:             AppColors.surfaceLight,
      onSurface:           AppColors.onSurfaceLight,
      surfaceContainerHighest: AppColors.surfaceVariantLight,
      onSurfaceVariant:    AppColors.onSurfaceVariantLight,
      outline:             AppColors.outlineLight,
      shadow:              Colors.black,
      inverseSurface:      AppColors.surfaceDark,
      onInverseSurface:    AppColors.onSurfaceDark,
      inversePrimary:      AppColors.primaryLight,
      scrim:               Colors.black,
    );

    return ThemeData(
      useMaterial3:     true,
      colorScheme:      scheme,
      scaffoldBackgroundColor: AppColors.backgroundLight,
      textTheme:        _buildTextTheme(AppColors.onSurfaceLight, AppColors.onSurfaceVariantLight),
      appBarTheme: AppBarTheme(
        backgroundColor:        AppColors.backgroundLight,
        foregroundColor:        AppColors.onSurfaceLight,
        elevation:              0,
        scrolledUnderElevation: 0,
        centerTitle:            true,
        titleTextStyle: const TextStyle(
          fontFamily: _fontFamily,
          fontSize:   18,
          fontWeight: FontWeight.w700,
          color:      AppColors.onSurfaceLight,
        ),
        // Subtle warm cashmere bottom border
        shape: const Border(
          bottom: BorderSide(color: Color(0xFFEFE8DA), width: 1.2),
        ),
      ),
      cardTheme: CardThemeData(
        color:       AppColors.surfaceLight,
        elevation:   1.5,
        shadowColor: Colors.black.withOpacity(0.04),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        margin: EdgeInsets.zero,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.poshObsidian,           // Midnight obsidian for smart posh look
          foregroundColor: Colors.white,
          elevation:       0,
          minimumSize:     const Size(double.infinity, 56),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(
            fontFamily:    _fontFamily,
            fontSize:      16,
            fontWeight:    FontWeight.w700,
            letterSpacing: 0.5,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.poshObsidian,
          side:            const BorderSide(color: AppColors.poshObsidian, width: 1.5),
          minimumSize:     const Size(double.infinity, 56),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(
            fontFamily:  _fontFamily,
            fontSize:    16,
            fontWeight:  FontWeight.w700,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.poshGold,
          textStyle: const TextStyle(
            fontFamily: _fontFamily,
            fontSize:   14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled:      true,
        fillColor:   AppColors.surfaceVariantLight,
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide:   BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide:   BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide:   const BorderSide(color: AppColors.poshGold, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide:   const BorderSide(color: AppColors.error, width: 1.5),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide:   const BorderSide(color: AppColors.error, width: 2),
        ),
        hintStyle: const TextStyle(
          fontFamily: _fontFamily,
          color:      AppColors.onSurfaceVariantLight,
          fontSize:   14,
        ),
        labelStyle: const TextStyle(
          fontFamily: _fontFamily,
          color:      AppColors.onSurfaceVariantLight,
          fontSize:   14,
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor:  AppColors.surfaceVariantLight,
        selectedColor:    AppColors.poshGold.withOpacity(0.18),
        labelStyle: const TextStyle(fontFamily: _fontFamily, fontSize: 13),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        side: BorderSide.none,
      ),
      dividerTheme: const DividerThemeData(
        color:     Color(0xFFECE5D8),   // Soft warm divider
        thickness: 1,
        space:     1,
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor:      AppColors.surfaceLight,
        selectedItemColor:    AppColors.poshGold,           // Regal gold selected icons
        unselectedItemColor:  AppColors.onSurfaceVariantLight,
        showUnselectedLabels: true,
        elevation:            10,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor:  AppColors.onSurfaceLight,
        contentTextStyle: const TextStyle(fontFamily: _fontFamily, color: Colors.white),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        behavior: SnackBarBehavior.floating,
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.poshObsidian,
        foregroundColor: Colors.white,                   // White icon on obsidian FAB
        elevation:       4,
        shape: CircleBorder(),
      ),
      switchTheme: SwitchThemeData(
        thumbColor:  WidgetStateProperty.resolveWith((s) =>
            s.contains(WidgetState.selected) ? AppColors.poshGold : null),
        trackColor:  WidgetStateProperty.resolveWith((s) =>
            s.contains(WidgetState.selected) ? AppColors.poshGold.withOpacity(0.35) : null),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.poshGold,
      ),
      tabBarTheme: const TabBarThemeData(
        labelColor:         AppColors.poshObsidian,         // Crisp midnight obsidian active tab
        unselectedLabelColor: AppColors.onSurfaceVariantLight,
        indicatorColor:     AppColors.poshGold,             // Regal gold underline indicator
        indicatorSize:      TabBarIndicatorSize.label,
        labelStyle:         TextStyle(fontFamily: _fontFamily, fontWeight: FontWeight.w700, fontSize: 14),
        unselectedLabelStyle: TextStyle(fontFamily: _fontFamily, fontWeight: FontWeight.w500, fontSize: 14),
      ),
    );
  }

  // ── Dark Theme ────────────────────────────────────────────────────────────
  static ThemeData get dark {
    final scheme = ColorScheme(
      brightness:          Brightness.dark,
      primary:             AppColors.primaryLight,           // Lighter yellow in dark
      onPrimary:           _onPrimary,                       // BLACK on yellow (dark too)
      primaryContainer:    AppColors.primaryDark,
      onPrimaryContainer:  AppColors.primaryLight,
      secondary:           AppColors.secondary,
      onSecondary:         Colors.white,
      secondaryContainer:  const Color(0xFF5C2000),
      onSecondaryContainer:const Color(0xFFFFDCBD),
      tertiary:            AppColors.tertiary,
      onTertiary:          Colors.white,
      tertiaryContainer:   const Color(0xFF00363E),
      onTertiaryContainer: const Color(0xFFB8F0F8),
      error:               const Color(0xFFFF6B6B),
      onError:             Colors.black,
      errorContainer:      const Color(0xFF93000A),
      onErrorContainer:    const Color(0xFFFFDAD6),
      surface:             AppColors.surfaceDark,
      onSurface:           AppColors.onSurfaceDark,
      surfaceContainerHighest: AppColors.surfaceVariantDark,
      onSurfaceVariant:    AppColors.onSurfaceVariantDark,
      outline:             AppColors.outlineDark,
      shadow:              Colors.black,
      inverseSurface:      AppColors.onSurfaceLight,
      onInverseSurface:    AppColors.backgroundLight,
      inversePrimary:      AppColors.primary,
      scrim:               Colors.black,
    );

    return ThemeData(
      useMaterial3:     true,
      colorScheme:      scheme,
      scaffoldBackgroundColor: AppColors.backgroundDark,
      textTheme:        _buildTextTheme(AppColors.onSurfaceDark, AppColors.onSurfaceVariantDark),
      appBarTheme: AppBarTheme(
        backgroundColor:        AppColors.backgroundDark,
        foregroundColor:        AppColors.onSurfaceDark,
        elevation:              0,
        scrolledUnderElevation: 0,
        centerTitle:            true,
        titleTextStyle: const TextStyle(
          fontFamily: _fontFamily,
          fontSize:   18,
          fontWeight: FontWeight.w700,
          color:      AppColors.onSurfaceDark,
        ),
        shape: const Border(
          bottom: BorderSide(color: Color(0xFF3D3820), width: 1),
        ),
      ),
      cardTheme: CardThemeData(
        color:       AppColors.surfaceDark,
        elevation:   0,
        shadowColor: Colors.black38,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.outlineDark, width: 1),
        ),
        margin: EdgeInsets.zero,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primaryLight,
          foregroundColor: _onPrimary,                       // BLACK text on yellow
          elevation:       0,
          minimumSize:     const Size(double.infinity, 56),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(
            fontFamily:    _fontFamily,
            fontSize:      16,
            fontWeight:    FontWeight.w700,
            letterSpacing: 0.5,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primaryLight,
          side:            const BorderSide(color: AppColors.primaryLight, width: 2),
          minimumSize:     const Size(double.infinity, 56),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(
            fontFamily:  _fontFamily,
            fontSize:    16,
            fontWeight:  FontWeight.w700,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primaryLight,
          textStyle: const TextStyle(
            fontFamily: _fontFamily,
            fontSize:   14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled:      true,
        fillColor:   AppColors.surfaceVariantDark,
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide:   BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide:   const BorderSide(color: AppColors.outlineDark, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide:   const BorderSide(color: AppColors.primaryLight, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide:   const BorderSide(color: AppColors.error, width: 1.5),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide:   const BorderSide(color: AppColors.error, width: 2),
        ),
        hintStyle: const TextStyle(
          fontFamily: _fontFamily,
          color:      AppColors.onSurfaceVariantDark,
          fontSize:   14,
        ),
        labelStyle: const TextStyle(
          fontFamily: _fontFamily,
          color:      AppColors.onSurfaceVariantDark,
          fontSize:   14,
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor:  AppColors.surfaceVariantDark,
        selectedColor:    AppColors.primaryLight.withOpacity(0.25),
        labelStyle: const TextStyle(fontFamily: _fontFamily, fontSize: 13, color: AppColors.onSurfaceDark),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        side: const BorderSide(color: AppColors.outlineDark, width: 0.8),
      ),
      dividerTheme: const DividerThemeData(
        color:     AppColors.outlineDark,
        thickness: 1,
        space:     1,
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor:      AppColors.surfaceDark,
        selectedItemColor:    AppColors.primaryLight,
        unselectedItemColor:  AppColors.onSurfaceVariantDark,
        showUnselectedLabels: true,
        elevation:            10,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor:  AppColors.surfaceVariantDark,
        contentTextStyle: const TextStyle(fontFamily: _fontFamily, color: AppColors.onSurfaceDark),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        behavior: SnackBarBehavior.floating,
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.primaryLight,
        foregroundColor: _onPrimary,                         // BLACK icon on yellow FAB
        elevation:       4,
        shape: CircleBorder(),
      ),
      switchTheme: SwitchThemeData(
        thumbColor:  WidgetStateProperty.resolveWith((s) =>
            s.contains(WidgetState.selected) ? AppColors.primaryLight : null),
        trackColor:  WidgetStateProperty.resolveWith((s) =>
            s.contains(WidgetState.selected) ? AppColors.primaryLight.withOpacity(0.4) : null),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.primaryLight,
      ),
      tabBarTheme: const TabBarThemeData(
        labelColor:           AppColors.primaryLight,
        unselectedLabelColor: AppColors.onSurfaceVariantDark,
        indicatorColor:       AppColors.primaryLight,
        indicatorSize:        TabBarIndicatorSize.label,
        labelStyle:           TextStyle(fontFamily: _fontFamily, fontWeight: FontWeight.w700, fontSize: 14),
        unselectedLabelStyle: TextStyle(fontFamily: _fontFamily, fontWeight: FontWeight.w500, fontSize: 14),
      ),
    );
  }

  // ── Elevation helpers ─────────────────────────────────────────────────────
  static const double elevationS = 2.0;
  static const double elevationM = 6.0;
  static const double elevationL = 12.0;
}
