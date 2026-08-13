import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Same four hex values as the web app's brand palette
/// (resources/views/components/guest-layout.blade.php's :root block) —
/// kept identical so the mobile app and web app feel like the same
/// product, not a reskinned clone.
class AppColors {
  static const forest = Color(0xFF00897B); // --brand-1
  static const sage = Color(0xFF73BEB6); // --brand-2
  static const tan = Color(0xFFBB8A52); // reserved accent, not used structurally on web either
  static const gold = Color(0xFFFFBA00); // focus/highlight accent — use sparingly (~10% rule), not as a default field/button color

  // Semantic colors — match the web app's Tailwind rose/emerald/amber
  // usage for danger/success/warning, not the brand colors. Screens
  // should use these explicitly rather than Colors.red/green/orange, so
  // a status color is never confused with the brand color.
  static const danger = Color(0xFFE11D48); // rose-600
  static const success = Color(0xFF059669); // emerald-600
  static const warning = Color(0xFFD97706); // amber-600

  // Text hierarchy — three defined grays instead of plain black/grey,
  // matching the web app's slate scale. This does more for a
  // "polished" feel than almost any other single change.
  static const textPrimary = Color(0xFF1E293B); // slate-800
  static const textSecondary = Color(0xFF64748B); // slate-500
  static const textTertiary = Color(0xFF94A3B8); // slate-400

  // Field surface — a subtle tint rather than plain white, so fields
  // register as distinct surfaces against the near-white scaffold
  // background instead of blending into it.
  static const fieldFill = Color(0xFFF1F5F9); // slate-100
  static const fieldBorder = Color(0xFFCBD5E1); // slate-300
}

class AppTheme {
  /// All four parameters are optional so every existing call site
  /// (screens that don't know about per-user theming) keeps working
  /// unchanged. fontSizeScale is a multiplier (1.0 = normal, matching
  /// User::fontSize()'s 100 = normal on the Laravel side) applied to
  /// every text style below, so headings/body/labels all stay
  /// proportional to each other rather than becoming one fixed size.
  static ThemeData light({
    Color? primaryColor,
    Color? secondaryColor,
    String? fontFamily,
    double fontSizeScale = 1.0,
  }) {
    final primary = primaryColor ?? AppColors.forest;
    final secondary = secondaryColor ?? AppColors.sage;

    final colorScheme = ColorScheme.fromSeed(
      seedColor: primary,
      primary: primary,
      secondary: secondary,
      error: AppColors.danger,
      brightness: Brightness.light,
    );

    // 'System' intentionally skips google_fonts entirely and falls
    // back to the OS's own default font. A genuinely null fontFamily
    // (pre-login/splash screens, where there's no user object yet to
    // read a preference from) defaults to Lato instead of also
    // falling through to no custom font — otherwise every screen
    // before login would look different from every screen after it.
    final effectiveFontFamily = fontFamily ?? 'Lato';
    TextStyle Function({required TextStyle textStyle}) applyFont =
        ({required TextStyle textStyle}) => textStyle;
    if (effectiveFontFamily != 'System') {
      try {
        applyFont = ({required TextStyle textStyle}) => GoogleFonts.getFont(effectiveFontFamily, textStyle: textStyle);
      } catch (_) {
        // Unrecognized family name — falls back to the system font
        // rather than crashing the whole app over a cosmetic setting.
      }
    }

    double s(double base) => base * fontSizeScale;

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      // A light tint of the ACTUAL chosen primary color, not a fixed
      // slate — subtle (5% blend into white) so this stays safely
      // light regardless of which primary color a user picks,
      // including bright ones like the sticky-notes Yellow.
      scaffoldBackgroundColor: Color.alphaBlend(primary.withValues(alpha: 0.05), Colors.white),
      textTheme: TextTheme(
        headlineSmall: applyFont(textStyle: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: s(24))),
        titleLarge: applyFont(textStyle: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: s(22))),
        titleMedium: applyFont(textStyle: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600, fontSize: s(16))),
        titleSmall: applyFont(textStyle: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600, fontSize: s(14))),
        bodyLarge: applyFont(textStyle: TextStyle(color: AppColors.textPrimary, fontSize: s(16))),
        bodyMedium: applyFont(textStyle: TextStyle(color: AppColors.textSecondary, fontSize: s(14))),
        bodySmall: applyFont(textStyle: TextStyle(color: AppColors.textTertiary, fontSize: s(12))),
        // These three were previously left unset entirely, silently
        // falling back to Material 3's auto-derived colorScheme.onSurface
        // — fine with the default seed color, but capable of mismatching
        // badly against this app's manually-fixed scaffoldBackgroundColor
        // once an unusual seed color (e.g. a bright sticky-notes Yellow)
        // is in play. Explicit, guaranteed-readable colors instead.
        labelLarge: applyFont(textStyle: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600, fontSize: s(14))),
        labelMedium: applyFont(textStyle: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w500, fontSize: s(12))),
        labelSmall: applyFont(textStyle: TextStyle(color: AppColors.textTertiary, fontWeight: FontWeight.w500, fontSize: s(11))),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: primary,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          disabledBackgroundColor: primary.withValues(alpha: 0.4),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primary,
          side: BorderSide(color: primary),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.fieldFill,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        labelStyle: const TextStyle(color: AppColors.textSecondary),
        floatingLabelStyle: TextStyle(color: secondary, fontWeight: FontWeight.w600),
        hintStyle: const TextStyle(color: AppColors.textTertiary),
        prefixIconColor: AppColors.textTertiary,
        suffixIconColor: AppColors.textTertiary,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.fieldBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.fieldBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: secondary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.danger),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.danger, width: 2),
        ),
        errorStyle: const TextStyle(color: AppColors.danger),
      ),
      cardTheme: CardThemeData(
        elevation: 1,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        color: Colors.white,
        margin: EdgeInsets.zero,
      ),
      dividerTheme: const DividerThemeData(color: Color(0xFFE2E8F0)), // slate-200
    );
  }
}
