import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// AllDebrid - Refined Dark Theme with Warm Amber Accents
/// Professional, clean, intentional design
class AppTheme {
  // Primary - Warm Amber/Orange
  static const Color primaryColor = Color(0xFFE8A634); // Refined amber
  static const Color primaryLight = Color(0xFFF5C55C);
  static const Color primaryDark = Color(0xFFCC8C1F);

  // Accent - Deep Orange
  static const Color accentColor = Color(0xFFD5722A);
  static const Color accentLight = Color(0xFFE8945A);
  static const Color accentDark = Color(0xFFB85A1A);

  // Status
  static const Color successColor = Color(0xFF5CB85C);
  static const Color warningColor = Color(0xFFE8A634);
  static const Color errorColor = Color(0xFFD9534F);
  static const Color infoColor = Color(0xFF5BC0DE);

  // Backgrounds - Rich blacks with warmth
  static const Color backgroundColor = Color(0xFF0C0C0E);
  static const Color surfaceColor = Color(0xFF121214);
  static const Color cardColor = Color(0xFF18181B);
  static const Color elevatedColor = Color(0xFF1F1F23);

  // Borders
  static const Color borderColor = Color(0xFF27272A);
  static const Color borderLight = Color(0xFF3F3F46);

  // Text - Warm whites
  static const Color textPrimary = Color(0xFFFAFAF9);
  static const Color textSecondary = Color(0xFFA1A1AA);
  static const Color textTertiary = Color(0xFF71717A);
  static const Color textMuted = Color(0xFF52525B);

  // Card without glow - clean flat design
  static BoxDecoration cardDecoration({
    double borderRadius = 12,
    bool elevated = false,
  }) {
    return BoxDecoration(
      color: elevated ? elevatedColor : cardColor,
      borderRadius: BorderRadius.circular(borderRadius),
      border: Border.all(color: borderColor, width: 1),
    );
  }

  // Compact card
  static BoxDecoration compactCardDecoration({double borderRadius = 10}) {
    return BoxDecoration(
      color: cardColor,
      borderRadius: BorderRadius.circular(borderRadius),
      border: Border.all(color: borderColor, width: 1),
    );
  }

  // Accent bordered card
  static BoxDecoration accentCardDecoration({
    required Color accent,
    double borderRadius = 12,
  }) {
    return BoxDecoration(
      color: cardColor,
      borderRadius: BorderRadius.circular(borderRadius),
      border: Border.all(color: accent.withValues(alpha: 0.4), width: 1.5),
    );
  }

  // Icon container - simple background
  static BoxDecoration iconContainerDecoration({
    required Color color,
    bool isCircle = false,
  }) {
    return BoxDecoration(
      color: color.withValues(alpha: 0.1),
      shape: isCircle ? BoxShape.circle : BoxShape.rectangle,
      borderRadius: isCircle ? null : BorderRadius.circular(10),
    );
  }

  // Light Mode Colors
  static const Color backgroundColorLight = Color(0xFFF2F4F7);
  static const Color surfaceColorLight = Color(0xFFFFFFFF);
  static const Color cardColorLight = Color(0xFFFFFFFF);
  static const Color elevatedColorLight = Color(0xFFFFFFFF);

  static const Color borderColorLight = Color(0xFFE4E7EC);
  static const Color textPrimaryLight = Color(0xFF101828);
  static const Color textSecondaryLight = Color(0xFF475467);
  static const Color textTertiaryLight = Color(0xFF667085);
  static const Color textMutedLight = Color(0xFF98A2B3);

  // Theme Data
  static ThemeData createTheme(Color primaryColor, {bool isDark = true}) {
    // Generate derived colors based on primary
    final Color primaryDark = HSLColor.fromColor(primaryColor)
        .withLightness(isDark ? 0.4 : 0.3)
        .toColor();

    // Select colors based on brightness
    final bgColor = isDark ? backgroundColor : backgroundColorLight;
    final surface = isDark ? surfaceColor : surfaceColorLight;
    final card = isDark ? cardColor : cardColorLight;
    final elevated = isDark ? elevatedColor : elevatedColorLight;
    final border = isDark ? borderColor : borderColorLight;
    final textP = isDark ? textPrimary : textPrimaryLight;
    final textS = isDark ? textSecondary : textSecondaryLight;
    final textT = isDark ? textTertiary : textTertiaryLight;
    final textM = isDark ? textMuted : textMutedLight;

    return ThemeData(
      useMaterial3: true,
      brightness: isDark ? Brightness.dark : Brightness.light,
      primaryColor: primaryColor,
      scaffoldBackgroundColor: bgColor,
      fontFamily: GoogleFonts.poppins().fontFamily,
      colorScheme: isDark
          ? ColorScheme.dark(
              primary: primaryColor,
              primaryContainer: primaryDark,
              secondary: primaryColor,
              secondaryContainer: primaryDark,
              surface: surface,
              error: errorColor,
              onPrimary: const Color(0xFF0C0C0E),
              onSecondary: const Color(0xFF0C0C0E),
              onSurface: textP,
              onError: textP,
            )
          : ColorScheme.light(
              primary: primaryColor,
              primaryContainer: primaryDark,
              secondary: primaryColor,
              secondaryContainer: primaryDark,
              surface: surface,
              error: errorColor,
              onPrimary: Colors.white,
              onSecondary: Colors.white,
              onSurface: textP,
              onError: Colors.white,
            ),
      appBarTheme: AppBarTheme(
        backgroundColor: bgColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: textP,
          letterSpacing: -0.3,
        ),
        iconTheme: IconThemeData(color: textP, size: 22),
      ),
      cardTheme: CardThemeData(
        color: card,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: border, width: 1),
        ),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: surface,
        selectedItemColor: primaryColor,
        unselectedItemColor: textM,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
        selectedLabelStyle:
            const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
        unselectedLabelStyle: const TextStyle(fontSize: 11),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: primaryColor,
        foregroundColor: isDark ? backgroundColor : Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        isDense: true,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: primaryColor, width: 1.5),
        ),
        hintStyle: TextStyle(color: textM, fontSize: 14),
        labelStyle: TextStyle(color: textS, fontSize: 14),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: isDark ? backgroundColor : Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          minimumSize: const Size(0, 46),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primaryColor,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          minimumSize: const Size(0, 38),
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
        ),
      ),
      iconTheme: IconThemeData(color: textS, size: 22),
      dividerTheme: DividerThemeData(color: border, thickness: 1, space: 0),
      listTileTheme: ListTileThemeData(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        dense: false,
        minVerticalPadding: 6,
        iconColor: textS,
        textColor: textP,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: surface,
        selectedColor: primaryColor,
        labelStyle: TextStyle(color: textP, fontSize: 12),
        side: BorderSide(color: border),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: card,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        titleTextStyle:
            TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: textP),
        contentTextStyle: TextStyle(fontSize: 14, color: textS),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: elevated,
        contentTextStyle: TextStyle(color: textP, fontSize: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        behavior: SnackBarBehavior.floating,
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: primaryColor,
        linearTrackColor: border,
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: primaryColor,
        unselectedLabelColor: textM,
        indicatorSize: TabBarIndicatorSize.label,
        labelStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        unselectedLabelStyle:
            const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
      ),
      textTheme: TextTheme(
        headlineLarge: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: textP,
            letterSpacing: -0.5,
            fontFamily: 'Roboto'),
        headlineMedium: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: textP,
            letterSpacing: -0.3,
            fontFamily: 'Roboto'),
        headlineSmall:
            TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: textP, fontFamily: 'Roboto'),
        titleLarge:
            TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: textP, fontFamily: 'Roboto'),
        titleMedium:
            TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: textP),
        titleSmall:
            TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: textP),
        bodyLarge:
            TextStyle(fontSize: 15, fontWeight: FontWeight.w400, color: textS),
        bodyMedium:
            TextStyle(fontSize: 14, fontWeight: FontWeight.w400, color: textS),
        bodySmall:
            TextStyle(fontSize: 12, fontWeight: FontWeight.w400, color: textT),
        labelLarge:
            TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: textP),
        labelMedium:
            TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: textS),
        labelSmall:
            TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: textT),
      ),
    );
  }
}
