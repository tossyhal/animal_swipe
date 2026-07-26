import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../constants/app_constants.dart';
import '../constants/app_strings.dart';

/// アプリのテーマ設定を管理するクラス
class AppTheme {
  AppTheme._();

  /// 2 色間の WCAG コントラスト比
  static double _contrastRatio(Color a, Color b) {
    final la = a.computeLuminance();
    final lb = b.computeLuminance();
    final lighter = math.max(la, lb);
    final darker = math.min(la, lb);
    return (lighter + 0.05) / (darker + 0.05);
  }

  /// [background] の上に乗せる前景色を、ブランドの 2 色
  /// （[AppColors.canvas] / [AppColors.ink]）のうち
  /// コントラストの高い方から機械的に選ぶ。
  /// 手書きで on 系の色を決め打ちしないための補助。
  @visibleForTesting
  static Color onColorFor(Color background) {
    return _contrastRatio(background, AppColors.canvas) >=
            _contrastRatio(background, AppColors.ink)
        ? AppColors.canvas
        : AppColors.ink;
  }

  /// シード色から M3 の派生色をすべて生成し、
  /// ブランド固有のアクセント色だけを上書きする。
  ///
  /// `primary` / `surface` 系はあえて上書きしない。
  /// トーナルパレット全体の整合性（`surfaceContainerLowest` 〜
  /// `surfaceContainerHighest`、`outlineVariant`、`onSurfaceVariant` など）は
  /// `fromSeed` に任せる方が破綻しないため。
  @visibleForTesting
  static ColorScheme buildColorScheme(Brightness brightness) {
    final base = ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      brightness: brightness,
    );
    return base.copyWith(
      secondary: AppColors.secondary,
      onSecondary: onColorFor(AppColors.secondary),
      tertiary: AppColors.tertiary,
      onTertiary: onColorFor(AppColors.tertiary),
      error: AppColors.error,
      onError: onColorFor(AppColors.error),
    );
  }

  /// 共通のTextTheme設定
  ///
  /// 色は指定しない。`ThemeData` が `colorScheme.onSurface` を基準に
  /// 自動で解決するため、テーマごとに色を渡す必要はない。
  static TextTheme _buildTextTheme() {
    return const TextTheme(
      titleLarge: TextStyle(
        fontFamily: AppStrings.fontFamily,
        fontWeight: FontWeight.bold,
        fontSize: AppConstants.fontSizeXXLarge,
      ),
      bodyLarge: TextStyle(
        fontFamily: AppStrings.fontFamily,
        fontSize: AppConstants.fontSizeMedium,
      ),
      bodyMedium: TextStyle(
        fontFamily: AppStrings.fontFamily,
        fontSize: AppConstants.fontSizeSmall,
      ),
    );
  }

  /// 共通のCardTheme設定
  static CardThemeData _buildCardTheme() {
    return CardThemeData(
      elevation: AppConstants.elevationMedium,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppConstants.borderRadiusLarge),
      ),
    );
  }

  /// 共通のElevatedButtonTheme設定
  static ElevatedButtonThemeData _buildElevatedButtonTheme(
    ColorScheme colorScheme,
  ) {
    return ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
        elevation: AppConstants.elevationLow,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppConstants.borderRadiusMedium),
        ),
        padding: const EdgeInsets.symmetric(
          vertical: AppConstants.paddingMedium,
        ),
      ),
    );
  }

  /// 共通のAppBarTheme設定
  static AppBarTheme _buildAppBarTheme(ColorScheme colorScheme) {
    return AppBarTheme(
      elevation: 0,
      backgroundColor: colorScheme.primary,
      foregroundColor: colorScheme.onPrimary,
      centerTitle: true,
      titleTextStyle: TextStyle(
        fontFamily: AppStrings.fontFamily,
        fontWeight: FontWeight.bold,
        fontSize: AppConstants.fontSizeXXLarge,
        color: colorScheme.onPrimary,
      ),
    );
  }

  static ThemeData _buildTheme(Brightness brightness) {
    final colorScheme = buildColorScheme(brightness);
    return ThemeData(
      colorScheme: colorScheme,
      textTheme: _buildTextTheme(),
      cardTheme: _buildCardTheme(),
      elevatedButtonTheme: _buildElevatedButtonTheme(colorScheme),
      appBarTheme: _buildAppBarTheme(colorScheme),
      useMaterial3: true,
      visualDensity: VisualDensity.standard,
    );
  }

  /// ライトテーマ
  static ThemeData lightTheme() => _buildTheme(Brightness.light);

  /// ダークテーマ
  static ThemeData darkTheme() => _buildTheme(Brightness.dark);
}
