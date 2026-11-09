import 'package:flutter/material.dart';

/// Taka Koi? colour system: "Obsidian & Gold".
///
/// Warm near-black and porcelain surfaces, one restrained gold accent, and
/// clear money colours (green = owed to you, red = you owe, amber = waiting).
///
/// Screens should prefer `context.palette` (see app_palette.dart), which
/// switches with light/dark mode. The constants here are the raw values it is
/// built from, plus a few named shades older widgets still use.
class AppColors {
  AppColors._();

  // ── Brand ─────────────────────────────────────────────────────────────────
  static const Color brandYellow  = Color(0xFFFFD700); // logo / launcher icon only
  static const Color primary      = Color(0xFFF0C24B); // gold accent (dark mode)
  static const Color primaryLight = Color(0xFFF6D77E);
  static const Color primaryDark  = Color(0xFFC9971A);
  static const Color secondary    = Color(0xFFE98A3C); // warm orange
  static const Color tertiary     = Color(0xFF5AA9F0); // sky

  // ── Dark mode surfaces ────────────────────────────────────────────────────
  static const Color backgroundDark       = Color(0xFF0B0A08);
  static const Color surfaceDark          = Color(0xFF15130F); // cards
  static const Color surfaceVariantDark   = Color(0xFF1E1B16); // inputs, raised
  static const Color surfaceSunkenDark    = Color(0xFF28241D); // chips, tracks
  static const Color outlineDark          = Color(0xFF2B2720); // hairlines
  static const Color onBackgroundDark     = Color(0xFFF3EEE2);
  static const Color onSurfaceDark        = Color(0xFFF3EEE2);
  static const Color onSurfaceVariantDark = Color(0xFFA49E8E);
  static const Color faintDark            = Color(0xFF6E695D);

  // ── Light mode surfaces ───────────────────────────────────────────────────
  static const Color backgroundLight       = Color(0xFFF6F4EF); // porcelain
  static const Color surfaceLight          = Color(0xFFFFFFFF);
  static const Color surfaceVariantLight   = Color(0xFFF0ECE4);
  static const Color surfaceSunkenLight    = Color(0xFFE8E3D8);
  static const Color outlineLight          = Color(0xFFE6E0D3);
  static const Color onBackgroundLight     = Color(0xFF17140F);
  static const Color onSurfaceLight        = Color(0xFF17140F);
  static const Color onSurfaceVariantLight = Color(0xFF6B6559);
  static const Color faintLight            = Color(0xFFA39C8E);

  // ── Gold & obsidian ───────────────────────────────────────────────────────
  static const Color gold          = Color(0xFFD4A537);
  static const Color goldBright    = Color(0xFFF2CC6B);
  static const Color goldDeep      = Color(0xFFB8861B);
  static const Color goldMist      = Color(0xFFF3E6C4);
  static const Color poshGold      = Color(0xFF946600); // gold that reads on white
  static const Color poshGoldLight = Color(0xFFC9A043);
  static const Color poshObsidian  = Color(0xFF17140F);
  static const Color obsidianLight = Color(0xFF2A251D);
  static const Color obsidianWarm  = Color(0xFF2A241D);
  static const Color ink           = Color(0xFF17140F); // text on gold
  static const Color inkMuted      = Color(0xBF17140F);
  static const Color amberDeep     = Color(0xFFC08A1E);
  static const Color amberBurnt    = Color(0xFFB86E12);
  static const Color yellowSoft    = Color(0xFFF6D77E);
  static const Color yellowPale    = Color(0xFFFBEFC4);

  // ── Money & status ────────────────────────────────────────────────────────
  static const Color success  = Color(0xFF1DB584); // owed to you, approved
  static const Color warning  = Color(0xFFF2A93B); // waiting
  static const Color error    = Color(0xFFEF5A5F); // you owe, rejected
  static const Color info     = Color(0xFF5AA9F0);
  static const Color iOwe     = error;
  static const Color owedToMe = success;
  static const Color pending  = warning;
  static const Color approved = success;
  static const Color rejected = error;

  // Readable text versions on light / dark backgrounds
  static const Color successTextLight = Color(0xFF0B7F5A);
  static const Color errorTextLight   = Color(0xFFC83A40);
  static const Color errorTextDark    = Color(0xFFFF8A8E);
  static const Color warningTextLight = Color(0xFF9A6200);

  // Status banners (background / border), light and dark
  static const Color successBgLight     = Color(0xFFE7F7F0);
  static const Color successBorderLight = Color(0xFFB4E6D2);
  static const Color successBgDark      = Color(0x241DB584);
  static const Color successBorderDark  = Color(0x551DB584);
  static const Color errorBgLight       = Color(0xFFFDEDEE);
  static const Color errorBorderLight   = Color(0xFFF6C7C9);
  static const Color errorBgDark        = Color(0x24EF5A5F);
  static const Color errorBorderDark    = Color(0x55EF5A5F);
  static const Color warningBgLight     = Color(0xFFFDF4E4);
  static const Color warningBorderLight = Color(0xFFF4DDB0);
  static const Color warningBgDark      = Color(0x24F2A93B);
  static const Color warningBorderDark  = Color(0x55F2A93B);
  static const Color goldBgLight        = Color(0xFFFBF4E2);
  static const Color goldBgDark         = Color(0x24F0C24B);
  static const Color goldBorderDark     = Color(0x55F0C24B);

  // ── Older named shades (kept so existing widgets compile) ─────────────────
  static const Color splashBlack       = backgroundDark;
  static const Color darkCardDeep      = Color(0xFF110F0C);
  static const Color darkHeroStart     = Color(0xFF221D15);
  static const Color darkHeroEnd       = Color(0xFF100E0B);
  static const Color darkCardEnd       = Color(0xFF13110D);
  static const Color darkPanel         = surfaceVariantDark;
  static const Color darkPanelAlt      = surfaceVariantDark;
  static const Color darkTile          = surfaceVariantDark;
  static const Color darkTileHighlight = surfaceSunkenDark;
  static const Color darkChip          = surfaceSunkenDark;
  static const Color darkInset         = surfaceSunkenDark;
  static const Color mutedLight        = onSurfaceVariantLight;
  static const Color mutedLightSoft    = faintLight;
  static const Color mutedDark         = onSurfaceVariantDark;
  static const Color mutedDarkSoft     = faintDark;
  static const Color textOnDark        = onSurfaceDark;
  static const Color disabledStart     = Color(0xFFBDB8AE);
  static const Color disabledEnd       = Color(0xFFCFCAC0);
  static const Color sandBorder        = outlineLight;
  static const Color switchTrackLight  = surfaceSunkenLight;
  static const Color sandChip          = surfaceVariantLight;
  static const Color sandTile          = surfaceVariantLight;
  static const Color sandTileHighlight = surfaceSunkenLight;
  static const Color ivoryCardEnd      = Color(0xFFFBFAF7);

  // ── Leaderboard medals ────────────────────────────────────────────────────
  static const Color silverLight  = Color(0xFFF1F3F6);
  static const Color silver       = Color(0xFF9AA5B4);
  static const Color silverInk    = Color(0xFF1E293B);
  static const Color bronzeLight  = Color(0xFFF3CDAE);
  static const Color bronze       = Color(0xFFA9653A);
  static const Color bronzeBorder = Color(0xFFF1D6C2);

  // ── Brands and avatars ────────────────────────────────────────────────────
  static const Color bkashPink    = Color(0xFFE2136E);
  static const Color avatarViolet = Color(0xFF8B6CF6);
  static const Color avatarPink   = Color(0xFFF0668A);
  static const Color avatarCyan   = Color(0xFF3FB6D3);

  /// Soft, distinct backgrounds for initials avatars.
  static const List<Color> avatarTones = [
    Color(0xFFD4A537), Color(0xFF3FB6D3), Color(0xFFF0668A), Color(0xFF8B6CF6),
    Color(0xFF1DB584), Color(0xFFE98A3C), Color(0xFF5AA9F0), Color(0xFFB57EDC),
  ];

  // ── Gradients ─────────────────────────────────────────────────────────────
  /// Gold foil: primary buttons in dark mode, accents.
  static const LinearGradient goldGradient = LinearGradient(
    colors: [Color(0xFFF6DA8A), Color(0xFFE2B044), Color(0xFFC08A1E)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// Obsidian card: the balance hero and other "black card" surfaces.
  static const LinearGradient heroGradient = LinearGradient(
    colors: [Color(0xFF241F17), Color(0xFF15120E), Color(0xFF0D0B08)],
    stops: [0, 0.55, 1],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient primaryGradient = goldGradient;
  static const LinearGradient cardGradient    = goldGradient;

  static const LinearGradient mintGradient = LinearGradient(
    colors: [Color(0xFF2BC795), Color(0xFF119C6E)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient darkSurfaceGradient = LinearGradient(
    colors: [surfaceVariantDark, surfaceDark],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  // ── Overlay ───────────────────────────────────────────────────────────────
  static const Color overlay = Color(0x99000000);
}
