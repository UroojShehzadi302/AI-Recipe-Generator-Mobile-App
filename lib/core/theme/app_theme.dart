import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_dimensions.dart';
import 'app_palette.dart';
import 'app_durations.dart';
import 'app_text_styles.dart';

/// Assembles [ThemeData] for CookMate AI from the design tokens.
///
/// This is the single place component defaults are set. Because the theme and
/// the reusable widgets (`PrimaryButton`, `AppTextField`, …) are driven by the
/// same tokens, they stay one design language rather than two competing specs —
/// a plain `ElevatedButton` dropped anywhere already looks correct.
class AppTheme {
  AppTheme._();

  /// The light theme — the palette the app has always shipped.
  static ThemeData get lightTheme => _themeFor(AppPalette.light);

  /// The dark theme.
  ///
  /// Built by the *same* builder as [lightTheme]. Every component default here
  /// is already expressed in `AppColors` tokens, and those resolve through
  /// [AppPalette.current], so pointing the palette at dark and re-running this
  /// produces a correctly themed dark `ThemeData` with no duplicated spec. Two
  /// hand-maintained copies would drift the moment anyone edited one.
  static ThemeData get darkTheme => _themeFor(AppPalette.dark);

  /// Builds a [ThemeData] with [palette] temporarily active.
  ///
  /// `MaterialApp` asks for `theme` and `darkTheme` in the same breath, so this
  /// cannot rely on whichever palette happens to be current — it swaps to the
  /// requested one, builds, and restores. The restore is in a `finally` so a
  /// throw mid-build cannot strand the app on the wrong palette.
  static ThemeData _themeFor(AppPalette palette) {
    final AppPalette previous = AppPalette.current;
    AppPalette.apply(palette);
    try {
      return _build(palette.brightness);
    } finally {
      AppPalette.apply(previous);
    }
  }

  static ThemeData _build(Brightness brightness) {
    final ColorScheme scheme = ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      brightness: brightness,
      primary: AppColors.primary,
      onPrimary: AppColors.onPrimary,
      surface: AppColors.surface,
      error: AppColors.error,
    );

    return ThemeData(
      brightness: brightness,
      useMaterial3: true,
      fontFamily: AppTextStyles.fontFamily,
      scaffoldBackgroundColor: AppColors.background,
      colorScheme: scheme,

      // Ripples are toned down — the default Material splash is heavy against
      // the soft cream/brown palette.
      splashFactory: InkSparkle.splashFactory,
      highlightColor: AppColors.primary.withValues(alpha: 0.04),

      // Smooth, consistent screen transitions on every platform.
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: <TargetPlatform, PageTransitionsBuilder>{
          TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        },
      ),

      // Transparent, flat app bar (premium minimal look).
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        foregroundColor: AppColors.textPrimary,
        titleTextStyle: AppTextStyles.sectionTitle,
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          disabledBackgroundColor: AppColors.disabled,
          disabledForegroundColor: AppColors.textDisabled,
          elevation: 0,
          minimumSize: const Size(double.infinity, AppDimensions.buttonHeight),
          textStyle: AppTextStyles.button,
          shape: RoundedRectangleBorder(borderRadius: AppDimensions.brMd),
          animationDuration: AppDurations.fast,
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primary,
          textStyle: AppTextStyles.button.copyWith(color: AppColors.primary),
          shape: RoundedRectangleBorder(borderRadius: AppDimensions.brSm),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          minimumSize: const Size(double.infinity, AppDimensions.buttonHeight),
          textStyle: AppTextStyles.button.copyWith(color: AppColors.primary),
          side: BorderSide(color: AppColors.border, width: 1.2),
          shape: RoundedRectangleBorder(borderRadius: AppDimensions.brMd),
        ),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppDimensions.fieldContentPadding,
          vertical: AppDimensions.fieldContentPadding,
        ),
        hintStyle: AppTextStyles.body.copyWith(color: AppColors.textTertiary),
        labelStyle: AppTextStyles.body.copyWith(color: AppColors.textSecondary),
        floatingLabelStyle: AppTextStyles.caption.copyWith(
          fontWeight: FontWeight.w600,
          color: AppColors.primary,
        ),
        errorStyle: AppTextStyles.caption.copyWith(color: AppColors.error),
        enabledBorder: OutlineInputBorder(
          borderRadius: AppDimensions.brMd,
          borderSide: BorderSide(color: AppColors.border, width: 1.2),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: AppDimensions.brMd,
          borderSide: BorderSide(color: AppColors.primary, width: 1.6),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: AppDimensions.brMd,
          borderSide: BorderSide(color: AppColors.error, width: 1.2),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: AppDimensions.brMd,
          borderSide: BorderSide(color: AppColors.error, width: 1.6),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: AppDimensions.brMd,
          borderSide: BorderSide(color: AppColors.borderSoft),
        ),
      ),

      cardTheme: CardThemeData(
        color: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: AppDimensions.brLg),
      ),

      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        titleTextStyle: AppTextStyles.sectionTitle,
        contentTextStyle: AppTextStyles.subtitle,
        shape: RoundedRectangleBorder(borderRadius: AppDimensions.brXl),
      ),

      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        showDragHandle: true,
        dragHandleColor: AppColors.border,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppDimensions.radiusXl),
          ),
        ),
      ),

      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.textPrimary,
        contentTextStyle: AppTextStyles.body.copyWith(color: Colors.white),
        actionTextColor: AppColors.secondary,
        elevation: 0,
        insetPadding: const EdgeInsets.all(AppDimensions.spaceL),
        shape: RoundedRectangleBorder(borderRadius: AppDimensions.brSm),
      ),

      dividerTheme: DividerThemeData(
        color: AppColors.borderSoft,
        thickness: 1,
        space: 1,
      ),

      chipTheme: ChipThemeData(
        backgroundColor: AppColors.surface,
        selectedColor: AppColors.primary,
        side: BorderSide(color: AppColors.border),
        labelStyle: AppTextStyles.caption,
        secondaryLabelStyle: AppTextStyles.caption,
        padding: const EdgeInsets.symmetric(
          horizontal: AppDimensions.spaceM,
          vertical: AppDimensions.spaceS,
        ),
        shape: RoundedRectangleBorder(borderRadius: AppDimensions.brPill),
      ),

      listTileTheme: ListTileThemeData(
        titleTextStyle: AppTextStyles.cardTitle,
        subtitleTextStyle: AppTextStyles.caption,
        iconColor: AppColors.primary,
      ),

      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: AppColors.primary,
        linearTrackColor: AppColors.primarySoft,
        circularTrackColor: Colors.transparent,
      ),

      textSelectionTheme: TextSelectionThemeData(
        cursorColor: AppColors.primary,
        selectionColor: AppColors.primary.withValues(alpha: 0.2),
        selectionHandleColor: AppColors.primary,
      ),

      iconTheme: IconThemeData(
        color: AppColors.textPrimary,
        size: AppDimensions.iconLg,
      ),

      textTheme: TextTheme(
        displaySmall: AppTextStyles.display,
        headlineMedium: AppTextStyles.screenTitle,
        titleLarge: AppTextStyles.sectionTitle,
        titleMedium: AppTextStyles.cardTitle,
        bodyLarge: AppTextStyles.body,
        bodyMedium: AppTextStyles.body,
        bodySmall: AppTextStyles.caption,
        labelSmall: AppTextStyles.label,
      ),
    );
  }
}
