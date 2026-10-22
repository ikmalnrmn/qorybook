import 'package:flutter/material.dart';

/// Gaya visual Qorybook: hangat, cerah, membulat, mudah disentuh anak.
class QColors {
  static const background = Color(0xFFFFF8EF);
  static const surface = Colors.white;
  static const primary = Color(0xFFFF7A45); // oranye Qory
  static const primaryDark = Color(0xFFE85D2A);
  static const sky = Color(0xFF4DA8FF);
  static const sun = Color(0xFFFFC93C);
  static const leaf = Color(0xFF4CC38A);
  static const grape = Color(0xFF8E6CEF);
  static const ink = Color(0xFF2B2D42);
  static const inkSoft = Color(0xFF6B6F80);
  static const line = Color(0xFFF0E6DA);
}

const _font = 'Nunito';

TextStyle _t(double size, FontWeight weight, {double height = 1.25, Color color = QColors.ink}) => TextStyle(
  fontFamily: _font,
  fontSize: size,
  fontWeight: weight,
  // Nunito variabel: atur sumbu ketebalan secara eksplisit.
  fontVariations: [FontVariation('wght', weight.value.toDouble())],
  height: height,
  color: color,
);

ThemeData buildTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: QColors.primary,
    primary: QColors.primary,
    secondary: QColors.sky,
    surface: QColors.surface,
    brightness: Brightness.light,
  );

  final text = TextTheme(
    displaySmall: _t(32, FontWeight.w900, height: 1.1),
    headlineMedium: _t(26, FontWeight.w900, height: 1.15),
    headlineSmall: _t(22, FontWeight.w800),
    titleLarge: _t(20, FontWeight.w800),
    titleMedium: _t(16, FontWeight.w800),
    titleSmall: _t(14, FontWeight.w700),
    bodyLarge: _t(16, FontWeight.w500, height: 1.5),
    bodyMedium: _t(14, FontWeight.w500, height: 1.45),
    bodySmall: _t(12, FontWeight.w600, color: QColors.inkSoft),
    labelLarge: _t(15, FontWeight.w800),
    labelMedium: _t(13, FontWeight.w700),
    labelSmall: _t(11, FontWeight.w700, color: QColors.inkSoft),
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: QColors.background,
    fontFamily: _font,
    textTheme: text,
    appBarTheme: AppBarTheme(
      backgroundColor: QColors.background,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: text.titleLarge,
      foregroundColor: QColors.ink,
    ),
    cardTheme: CardThemeData(
      color: QColors.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      margin: EdgeInsets.zero,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: QColors.primary,
        foregroundColor: Colors.white,
        minimumSize: const Size(56, 56),
        padding: const EdgeInsets.symmetric(horizontal: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        textStyle: text.labelLarge,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: QColors.ink,
        minimumSize: const Size(56, 56),
        side: const BorderSide(color: QColors.line, width: 2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        textStyle: text.labelLarge,
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: QColors.surface,
      selectedColor: QColors.primary.withValues(alpha: 0.15),
      side: const BorderSide(color: QColors.line, width: 1.5),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      labelStyle: text.labelMedium,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: QColors.surface,
      indicatorColor: QColors.primary.withValues(alpha: 0.16),
      height: 72,
      labelTextStyle: WidgetStatePropertyAll(text.labelMedium),
      surfaceTintColor: Colors.transparent,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: QColors.surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
      hintStyle: text.bodyLarge?.copyWith(color: QColors.inkSoft),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      contentTextStyle: text.bodyMedium?.copyWith(color: Colors.white),
    ),
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {TargetPlatform.android: FadeForwardsPageTransitionsBuilder()},
    ),
  );
}

/// Bayangan lembut untuk kartu.
const softShadow = [BoxShadow(color: Color(0x14000000), blurRadius: 18, offset: Offset(0, 6))];
