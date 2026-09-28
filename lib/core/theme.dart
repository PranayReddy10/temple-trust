import 'package:flutter/material.dart';

/// The temple palette, shared with the devotee app and `config/brand.php`.
class Palette {
  Palette._();

  static const Color saffron = Color(0xFFE07A1F);
  static const Color kumkum = Color(0xFF9B1B30);
  static const Color gold = Color(0xFFC9A227);
  static const Color sandal = Color(0xFFF5EBDC);
  static const Color deep = Color(0xFF3E2723);
  static const Color ivory = Color(0xFFFFF8EC);
  static const Color ebony = Color(0xFF1E120F);
  static const Color darkStone = Color(0xFF2B1B16);
  static const Color stone = Color(0xFFB8A48B);
  static const Color tulsi = Color(0xFF2E7D55);
}

/// Kumkum-led, like the temple portal, so a team member can tell at a glance
/// they are in the trust app and not the devotee app.
class TrustTheme {
  TrustTheme._();

  static ThemeData light() => _build(Brightness.light);
  static ThemeData dark() => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final surface = isDark ? Palette.ebony : Palette.sandal;
    final onSurface = isDark ? Palette.sandal : Palette.deep;
    final primary = isDark ? const Color(0xFFD9546B) : Palette.kumkum;

    final scheme = ColorScheme(
      brightness: brightness,
      primary: primary,
      onPrimary: Colors.white,
      secondary: Palette.gold,
      onSecondary: Palette.ebony,
      tertiary: Palette.saffron,
      onTertiary: Colors.white,
      error: const Color(0xFFB3261E),
      onError: Colors.white,
      surface: surface,
      onSurface: onSurface,
      surfaceContainerHighest: isDark ? Palette.darkStone : Palette.ivory,
      surfaceContainer: isDark ? const Color(0xFF2A1A15) : const Color(0xFFFAF2E4),
      outline: isDark ? Palette.gold.withValues(alpha: 0.35) : Palette.stone,
      outlineVariant: isDark ? Palette.gold.withValues(alpha: 0.18) : Palette.stone.withValues(alpha: 0.45),
    );

    final base = ThemeData(brightness: brightness, colorScheme: scheme, useMaterial3: true);
    final text = base.textTheme.apply(bodyColor: onSurface, displayColor: onSurface);

    return base.copyWith(
      scaffoldBackgroundColor: surface,
      textTheme: text.copyWith(
        headlineSmall: text.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
        titleLarge: text.titleLarge?.copyWith(fontWeight: FontWeight.w700),
        titleMedium: text.titleMedium?.copyWith(fontWeight: FontWeight.w600),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: surface,
        foregroundColor: onSurface,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        centerTitle: false,
      ),
      cardTheme: CardThemeData(
        color: scheme.surfaceContainerHighest,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: scheme.outlineVariant)),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          shape: const StadiumBorder(),
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          shape: const StadiumBorder(),
          side: BorderSide(color: scheme.primary),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainerHighest,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: scheme.outlineVariant)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: scheme.outlineVariant)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: scheme.primary, width: 1.6)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: Palette.deep,
        contentTextStyle: const TextStyle(color: Palette.sandal),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: isDark ? Palette.darkStone : Palette.ivory,
        indicatorColor: scheme.primary.withValues(alpha: 0.16),
      ),
    );
  }
}
