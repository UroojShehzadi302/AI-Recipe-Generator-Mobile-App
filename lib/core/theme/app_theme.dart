import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';
import 'app_dimensions.dart';
import 'app_text_styles.dart';

/// Assembles [ThemeData] for the AI Recipe Generator from the design tokens.
///
/// The button and input themes deliberately match the existing
/// `CustomButton` / `CustomTextField` look (height 55, radius 16, brown
/// primary, grey field borders) so the theme and the reusable widgets are a
/// single, consistent design language rather than two competing specs.
class AppTheme {
  AppTheme._();

  static ThemeData get lightTheme => ThemeData(
        useMaterial3: true,
        fontFamily: GoogleFonts.poppins().fontFamily,
        scaffoldBackgroundColor: AppColors.background,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.primary,
          brightness: Brightness.light,
          surface: AppColors.surface,
          error: AppColors.error,
        ),

        // Transparent, flat app bar (premium minimal look).
        appBarTheme: AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0,
          centerTitle: true,
          foregroundColor: AppColors.textPrimary,
          titleTextStyle: AppTextStyles.title,
        ),

        // Matches CustomButton: brown, white text, radius 16, elevation 4.
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            elevation: 4,
            shadowColor: AppColors.primary.withValues(alpha: 0.35),
            minimumSize: const Size(double.infinity, AppDimensions.buttonHeight),
            textStyle: AppTextStyles.button,
            shape: RoundedRectangleBorder(borderRadius: AppDimensions.brMd),
          ),
        ),

        // Matches CustomTextField: white fill, radius 16, grey border.
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: AppColors.surface,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: AppDimensions.fieldContentPadding,
            vertical: AppDimensions.fieldContentPadding,
          ),
          labelStyle: const TextStyle(
            fontSize: 15,
            color: AppColors.textSecondary,
          ),
          floatingLabelStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppColors.primary,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: AppDimensions.brMd,
            borderSide: const BorderSide(color: AppColors.border, width: 1.2),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: AppDimensions.brMd,
            borderSide: const BorderSide(color: AppColors.primary, width: 2),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: AppDimensions.brMd,
            borderSide: const BorderSide(color: AppColors.error),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: AppDimensions.brMd,
            borderSide: const BorderSide(color: AppColors.error, width: 2),
          ),
        ),
      );
}
