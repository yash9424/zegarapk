import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

/// Central place for the Zegar brand palette and theme configuration.
class AppColors {
  AppColors._();

  // Brand
  static const Color primary = Color(0xFFC1121F); // Zegar red
  static const Color primaryDark = Color(0xFF9E0E18);
  static const Color primaryLight = Color(0xFFE23744);

  // Backgrounds
  static const Color scaffold = Color(0xFFF3F5FB);
  static const Color surface = Colors.white;
  static const Color fieldFill = Color(0xFFF5F6FA);
  static const Color fieldBorder = Color(0xFFE6E8F0);

  // Text
  static const Color textPrimary = Color(0xFF1C2435);
  static const Color textSecondary = Color(0xFF6B7384);
  static const Color textMuted = Color(0xFF9AA1B1);

  // Misc
  static const Color softRedTint = Color(0xFFFCEFF0);
  static const Color divider = Color(0xFFE6E8F0);
}

class AppTheme {
  AppTheme._();

  static ThemeData get light {
    final base = ThemeData.light(useMaterial3: true);
    final textTheme = GoogleFonts.poppinsTextTheme(base.textTheme);

    return base.copyWith(
      scaffoldBackgroundColor: AppColors.scaffold,
      primaryColor: AppColors.primary,
      colorScheme: base.colorScheme.copyWith(
        primary: AppColors.primary,
        secondary: AppColors.primary,
        surface: AppColors.surface,
      ),
      textTheme: textTheme.apply(
        bodyColor: AppColors.textPrimary,
        displayColor: AppColors.textPrimary,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.surface,
        elevation: 0,
        scrolledUnderElevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle.dark,
        iconTheme: IconThemeData(color: AppColors.textPrimary),
      ),
    );
  }
}
