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
  /// 色も書体も指定しない。色は `ThemeData` が `colorScheme.onSurface` から、
  /// 書体は `ThemeData(fontFamily: ...)` が全ロールに一括で適用する。
  static TextTheme _buildTextTheme() {
    return const TextTheme(
      titleLarge: TextStyle(
        fontWeight: FontWeight.bold,
        fontSize: AppConstants.fontSizeXXLarge,
      ),
      bodyLarge: TextStyle(fontSize: AppConstants.fontSizeMedium),
      bodyMedium: TextStyle(fontSize: AppConstants.fontSizeSmall),
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
  ///
  /// `titleTextStyle` は `TextStyle` を直接組み立てず、
  /// `fontFamily` 適用済みの `textTheme.titleLarge` から派生させる。
  /// ここで新しい `TextStyle` を作ると `ThemeData(fontFamily: ...)` が
  /// 効かず、AppBar のタイトルだけ既定フォントに落ちてしまうため。
  static AppBarTheme _buildAppBarTheme(ThemeData base) {
    final colorScheme = base.colorScheme;
    return AppBarTheme(
      elevation: 0,
      backgroundColor: colorScheme.primary,
      foregroundColor: colorScheme.onPrimary,
      centerTitle: true,
      titleTextStyle: base.textTheme.titleLarge?.copyWith(
        color: colorScheme.onPrimary,
      ),
    );
  }

  static ThemeData _buildTheme(Brightness brightness) {
    final colorScheme = buildColorScheme(brightness);
    final base = ThemeData(
      colorScheme: colorScheme,
      // 書体はここで一括指定する。個々の TextStyle には書かない
      fontFamily: AppStrings.fontFamily,
      textTheme: _buildTextTheme(),
      cardTheme: _buildCardTheme(),
      elevatedButtonTheme: _buildElevatedButtonTheme(colorScheme),
      useMaterial3: true,
      visualDensity: VisualDensity.standard,
    );
    return base.copyWith(appBarTheme: _buildAppBarTheme(base));
  }

  /// ライトテーマ
  static ThemeData lightTheme() => _buildTheme(Brightness.light);

  /// ダークテーマ
  static ThemeData darkTheme() => _buildTheme(Brightness.dark);
}
