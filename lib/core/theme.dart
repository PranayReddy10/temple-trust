import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/material.dart';

/// The temple palette, shared with the devotee app and `config/brand.php`.
class Palette {
  Palette._();

  static const Color saffron = Color(0xFFE07A1F);
  static const Color kumkum = Color(0xFF9B1B30);
  static const Color kumkumDeep = Color(0xFF6E0F22);
  static const Color gold = Color(0xFFC9A227);
  static const Color goldLight = Color(0xFFE8CF7A);
  static const Color sandal = Color(0xFFF5EBDC);
  static const Color deep = Color(0xFF3E2723);
  static const Color ivory = Color(0xFFFFF8EC);
  static const Color paper = Color(0xFFFFFCF5);
  static const Color ebony = Color(0xFF1E120F);
  static const Color darkStone = Color(0xFF2B1B16);
  static const Color stone = Color(0xFFB8A48B);
  static const Color tulsi = Color(0xFF2E7D55);
  static const Color sky = Color(0xFF4A6FA5);

  /// Kumkum to deep maroon: the hero panels and the welcome backdrop.
  static const LinearGradient kumkumGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFB2263E), kumkum, kumkumDeep],
  );

  /// Saffron to gold: the counter's scan panel, so it is found at a glance.
  static const LinearGradient saffronGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFF08A2A), saffron, Color(0xFFC25F0C)],
  );

  /// Tulsi green: money received, verified, approved.
  static const LinearGradient tulsiGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF3B946A), tulsi, Color(0xFF1F5C3E)],
  );
}

/// Kumkum-led, like the temple portal, so a team member can tell at a glance
/// they are in the trust app and not the devotee app. A serif for headings
/// and a sans for everything else, with the Indic faces behind both.
class TrustTheme {
  TrustTheme._();

  static const serif = 'NotoSerif';
  static const sans = 'NotoSans';
  static const fallback = ['NotoSansDevanagari', 'NotoSansTelugu', 'NotoSansTamil', 'NotoSansKannada'];

  static const double radius = 20;

  static ThemeData light() => _build(Brightness.light);
  static ThemeData dark() => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final surface = isDark ? Palette.ebony : Palette.sandal;
    final onSurface = isDark ? Palette.sandal : Palette.deep;
    final card = isDark ? Palette.darkStone : Palette.paper;
    final primary = isDark ? const Color(0xFFE0617A) : Palette.kumkum;

    final scheme = ColorScheme(
      brightness: brightness,
      primary: primary,
      onPrimary: Colors.white,
      primaryContainer: isDark ? const Color(0xFF4A1A24) : const Color(0xFFF8DDE2),
      onPrimaryContainer: isDark ? const Color(0xFFFFD9E0) : Palette.kumkumDeep,
      secondary: Palette.gold,
      onSecondary: Palette.ebony,
      secondaryContainer: isDark ? const Color(0xFF4A3A10) : const Color(0xFFF7EBC4),
      onSecondaryContainer: isDark ? Palette.goldLight : const Color(0xFF5C4600),
      tertiary: Palette.saffron,
      onTertiary: Colors.white,
      tertiaryContainer: isDark ? const Color(0xFF4F2A0C) : const Color(0xFFFCE4CC),
      onTertiaryContainer: isDark ? const Color(0xFFFFD6B0) : const Color(0xFF6B3300),
      error: const Color(0xFFB3261E),
      onError: Colors.white,
      surface: surface,
      onSurface: onSurface,
      onSurfaceVariant: isDark ? Palette.stone : const Color(0xFF6E5B4E),
      surfaceContainerLowest: isDark ? const Color(0xFF170D0A) : Colors.white,
      surfaceContainerLow: isDark ? const Color(0xFF24150F) : const Color(0xFFFBF4E8),
      surfaceContainer: isDark ? const Color(0xFF2A1A15) : const Color(0xFFFAF2E4),
      surfaceContainerHigh: isDark ? const Color(0xFF33211B) : Palette.ivory,
      surfaceContainerHighest: card,
      outline: isDark ? Palette.gold.withValues(alpha: 0.35) : Palette.stone,
      outlineVariant: isDark ? Palette.gold.withValues(alpha: 0.16) : Palette.stone.withValues(alpha: 0.35),
      shadow: Colors.black,
      scrim: Colors.black,
      inverseSurface: isDark ? Palette.sandal : Palette.deep,
      onInverseSurface: isDark ? Palette.deep : Palette.sandal,
      inversePrimary: Palette.goldLight,
      surfaceTint: Colors.transparent,
    );

    final base = ThemeData(brightness: brightness, colorScheme: scheme, useMaterial3: true, fontFamily: sans, fontFamilyFallback: fallback);
    final text = base.textTheme.apply(bodyColor: onSurface, displayColor: onSurface, fontFamily: sans, fontFamilyFallback: fallback);
    TextStyle? heading(TextStyle? t, {double? size, double spacing = -0.2}) => t?.copyWith(fontFamily: serif, fontFamilyFallback: fallback, fontWeight: FontWeight.w600, letterSpacing: spacing, fontSize: size);

    final textTheme = text.copyWith(
      displayLarge: heading(text.displayLarge, spacing: -0.5),
      displayMedium: heading(text.displayMedium, spacing: -0.5),
      displaySmall: heading(text.displaySmall, spacing: -0.4),
      headlineLarge: heading(text.headlineLarge),
      headlineMedium: heading(text.headlineMedium),
      headlineSmall: heading(text.headlineSmall, size: 24),
      titleLarge: heading(text.titleLarge, size: 21),
      titleMedium: text.titleMedium?.copyWith(fontWeight: FontWeight.w700, letterSpacing: 0),
      titleSmall: text.titleSmall?.copyWith(fontWeight: FontWeight.w700),
      labelLarge: text.labelLarge?.copyWith(fontWeight: FontWeight.w700, letterSpacing: 0.2),
      labelSmall: text.labelSmall?.copyWith(letterSpacing: 1.2, fontWeight: FontWeight.w700),
      bodySmall: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant, height: 1.35),
      bodyMedium: text.bodyMedium?.copyWith(height: 1.4),
    );

    final shape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(radius));
    final cardShadow = [
      BoxShadow(color: (isDark ? Colors.black : Palette.deep).withValues(alpha: isDark ? 0.4 : 0.07), blurRadius: 18, offset: const Offset(0, 6)),
    ];

    return base.copyWith(
      scaffoldBackgroundColor: surface,
      textTheme: textTheme,
      iconTheme: IconThemeData(color: onSurface),
      splashFactory: InkSparkle.splashFactory,
      appBarTheme: AppBarTheme(
        backgroundColor: surface,
        foregroundColor: onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleSpacing: 4,
        titleTextStyle: textTheme.titleLarge,
        iconTheme: IconThemeData(color: onSurface),
      ),
      cardTheme: CardThemeData(
        color: card,
        elevation: 0,
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radius), side: BorderSide(color: scheme.outlineVariant)),
      ),
      listTileTheme: ListTileThemeData(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        iconColor: scheme.primary,
        titleTextStyle: textTheme.titleMedium,
        subtitleTextStyle: textTheme.bodySmall,
        shape: shape,
      ),
      dividerTheme: DividerThemeData(color: scheme.outlineVariant, space: 1, thickness: 1),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          shape: const StadiumBorder(),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          textStyle: textTheme.labelLarge?.copyWith(fontSize: 15),
          elevation: 0,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          shape: const StadiumBorder(),
          side: BorderSide(color: scheme.primary.withValues(alpha: 0.6), width: 1.4),
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
          textStyle: textTheme.labelLarge?.copyWith(fontSize: 15),
          foregroundColor: scheme.primary,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          shape: const StadiumBorder(),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          textStyle: textTheme.labelLarge,
          foregroundColor: scheme.primary,
        ),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: SegmentedButton.styleFrom(
          selectedBackgroundColor: scheme.primary,
          selectedForegroundColor: scheme.onPrimary,
          backgroundColor: card,
          side: BorderSide(color: scheme.outlineVariant),
          textStyle: textTheme.labelLarge,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        elevation: 4,
        extendedTextStyle: textTheme.labelLarge?.copyWith(fontSize: 15),
        shape: const StadiumBorder(),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: card,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: scheme.outlineVariant)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: scheme.outlineVariant)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: scheme.primary, width: 1.6)),
        errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: scheme.error)),
        focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: scheme.error, width: 1.6)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        labelStyle: textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
        hintStyle: textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant.withValues(alpha: 0.7)),
        prefixIconColor: scheme.onSurfaceVariant,
        suffixIconColor: scheme.onSurfaceVariant,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: scheme.surfaceContainer,
        selectedColor: scheme.primaryContainer,
        side: BorderSide(color: scheme.outlineVariant),
        shape: const StadiumBorder(),
        labelStyle: textTheme.labelLarge?.copyWith(fontSize: 13),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: Palette.deep,
        contentTextStyle: const TextStyle(color: Palette.sandal, fontFamily: sans, fontFamilyFallback: fallback),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        titleTextStyle: textTheme.titleLarge,
        contentTextStyle: textTheme.bodyMedium,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: card,
        showDragHandle: true,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        textStyle: textTheme.bodyMedium,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: card,
        indicatorColor: scheme.primary.withValues(alpha: 0.14),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? Colors.white : null),
        trackColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? scheme.primary : null),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: scheme.primary),
      pageTransitionsTheme: const PageTransitionsTheme(builders: {
        TargetPlatform.android: PredictiveBackPageTransitionsBuilder(),
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
      }),
      extensions: [TrustStyle(cardShadow: cardShadow, hero: isDark ? Palette.darkStone : Palette.kumkum)],
    );
  }
}

/// Decoration the theme cannot carry by itself: the soft card shadow and
/// the hero colour, read by the shared widgets.
class TrustStyle extends ThemeExtension<TrustStyle> {
  const TrustStyle({required this.cardShadow, required this.hero});

  final List<BoxShadow> cardShadow;
  final Color hero;

  static TrustStyle of(BuildContext context) => Theme.of(context).extension<TrustStyle>() ?? const TrustStyle(cardShadow: [], hero: Palette.kumkum);

  @override
  TrustStyle copyWith({List<BoxShadow>? cardShadow, Color? hero}) => TrustStyle(cardShadow: cardShadow ?? this.cardShadow, hero: hero ?? this.hero);

  @override
  TrustStyle lerp(TrustStyle? other, double t) => other == null ? this : TrustStyle(cardShadow: t < 0.5 ? cardShadow : other.cardShadow, hero: Color.lerp(hero, other.hero, t) ?? hero);
}
