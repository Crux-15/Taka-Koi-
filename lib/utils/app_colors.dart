import 'package:flutter/material.dart';

/// All colour constants used throughout the app.
/// Taka Koi! brand palette — yellow, black, warm orange.
class AppColors {
  AppColors._();

  // ── Brand Colours ─────────────────────────────────────────────────────────
  static const Color primary      = Color(0xFFFFD700); // Brand yellow
  static const Color primaryLight = Color(0xFFFFE957); // Lighter yellow for dark mode
  static const Color primaryDark  = Color(0xFFC8A800); // Deeper yellow for pressed states
  static const Color secondary    = Color(0xFFFF6D00); // Deep orange (playful accent)
  static const Color tertiary     = Color(0xFF00BCD4); // Cyan (cool contrast)

  // ── Light Theme ───────────────────────────────────────────────────────────
  static const Color backgroundLight       = Color(0xFFFFFBF0); // Warm cream — sunny feel
  static const Color surfaceLight          = Color(0xFFFFFFFF); // White cards
  static const Color surfaceVariantLight   = Color(0xFFFFF8E1); // Amber-tinted surface
  static const Color onBackgroundLight     = Color(0xFF1A1A1A); // Near black text
  static const Color onSurfaceLight        = Color(0xFF1A1A1A);
  static const Color onSurfaceVariantLight = Color(0xFF6D6457); // Warm brown-grey
  static const Color outlineLight          = Color(0xFFE8D78A); // Yellow-tinted outline

  // ── Dark Theme ────────────────────────────────────────────────────────────
  static const Color backgroundDark       = Color(0xFF0D0D0D); // Near black (logo bg)
  static const Color surfaceDark          = Color(0xFF1C1B18); // Warm dark surface
  static const Color surfaceVariantDark   = Color(0xFF2A2820); // Slightly lighter warm dark
  static const Color onBackgroundDark     = Color(0xFFF5F0DC); // Warm off-white
  static const Color onSurfaceDark        = Color(0xFFEEE9D5);
  static const Color onSurfaceVariantDark = Color(0xFFB0A880); // Warm muted gold
  static const Color outlineDark          = Color(0xFF3D3820); // Dark warm outline

  // ── Semantic ──────────────────────────────────────────────────────────────
  static const Color success = Color(0xFF00C896); // Vibrant green (clear meaning)
  static const Color warning = Color(0xFFFF9100); // Amber-orange (fits the theme)
  static const Color error   = Color(0xFFFF4757); // Vivid red (unchanged — critical)
  static const Color info    = Color(0xFF00BCD4); // Cyan (matches tertiary)

  // ── Debt Indicator ────────────────────────────────────────────────────────
  static const Color iOwe     = Color(0xFFFF4757); // I owe someone (red)
  static const Color owedToMe = Color(0xFF00C896); // Someone owes me (green)

  // ── Expense Status ────────────────────────────────────────────────────────
  static const Color pending  = Color(0xFFFF9100); // Amber-orange
  static const Color approved = Color(0xFF00C896); // Green
  static const Color rejected = Color(0xFFFF4757); // Red

  // ── Gradients ─────────────────────────────────────────────────────────────
  /// Yellow → Amber: used on primary action buttons/hero areas
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFFFFD700), Color(0xFFFF8F00)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// Dark warm gradient: used on dark hero banners / login backgrounds
  static const LinearGradient heroGradient = LinearGradient(
    colors: [Color(0xFF1A1600), Color(0xFF332C00)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// Green gradient: success & payment states
  static const LinearGradient mintGradient = LinearGradient(
    colors: [Color(0xFF00C896), Color(0xFF00A878)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// Yellow → Deep Orange: energetic card gradient
  static const LinearGradient cardGradient = LinearGradient(
    colors: [Color(0xFFFFD700), Color(0xFFFF6D00)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// Warm dark surface gradient for dark mode cards
  static const LinearGradient darkSurfaceGradient = LinearGradient(
    colors: [Color(0xFF2A2820), Color(0xFF1C1B18)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  // ── Overlay ───────────────────────────────────────────────────────────────
  static const Color overlay = Color(0x80000000);
}
