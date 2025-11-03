import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../constants/app_constants.dart';
import '../constants/app_strings.dart';

/// アプリのテーマ設定を管理するクラス
class AppTheme {
  AppTheme._();

  /// 共通のTextTheme設定
  static TextTheme _buildTextTheme({required Color textColor}) {
    return TextTheme(
      titleLarge: TextStyle(
        fontFamily: AppStrings.fontFamily,
        fontWeight: FontWeight.bold,
        fontSize: AppConstants.fontSizeXXLarge,
        color: textColor,
      ),
      bodyLarge: TextStyle(
        fontFamily: AppStrings.fontFamily,
        fontSize: AppConstants.fontSizeMedium,
        color: textColor,
      ),
      bodyMedium: TextStyle(
        fontFamily: AppStrings.fontFamily,
        fontSize: AppConstants.fontSizeSmall,
        color: textColor,
      ),
    );
  }

  /// 共通のCardTheme設定
  static CardTheme _buildCardTheme({Color? cardColor}) {
    return CardTheme(
      elevation: AppConstants.elevationMedium,
      color: cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppConstants.borderRadiusLarge),
      ),
    );
  }

  /// 共通のElevatedButtonTheme設定
  static ElevatedButtonThemeData _buildElevatedButtonTheme() {
    return ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
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
  static AppBarTheme _buildAppBarTheme({
    required Color backgroundColor,
    required Color foregroundColor,
  }) {
    return AppBarTheme(
      elevation: 0,
      backgroundColor: backgroundColor,
      foregroundColor: foregroundColor,
      centerTitle: true,
      titleTextStyle: TextStyle(
        fontFamily: AppStrings.fontFamily,
        fontWeight: FontWeight.bold,
        fontSize: AppConstants.fontSizeXXLarge,
      ),
    );
  }

  /// ライトテーマ
  static ThemeData lightTheme() {
    return ThemeData(
      colorScheme: const ColorScheme.light(
        primary: AppColors.primary,
        primaryContainer: AppColors.primaryContainer,
        onPrimaryContainer: AppColors.onPrimaryContainer,
        secondary: AppColors.secondary,
        tertiary: AppColors.tertiary,
        surface: Colors.white,
        error: AppColors.error,
      ),
      textTheme: _buildTextTheme(textColor: Colors.black),
      cardTheme: _buildCardTheme(),
      elevatedButtonTheme: _buildElevatedButtonTheme(),
      appBarTheme: _buildAppBarTheme(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      brightness: Brightness.light,
      useMaterial3: true,
    );
  }

  /// ダークテーマ
  static ThemeData darkTheme() {
    return ThemeData(
      colorScheme: const ColorScheme.dark(
        primary: AppColors.primary,
        primaryContainer: AppColors.onPrimaryContainer,
        onPrimaryContainer: AppColors.primaryContainer,
        secondary: AppColors.secondary,
        tertiary: AppColors.tertiary,
        surface: AppColors.darkSurface,
        error: AppColors.error,
      ),
      scaffoldBackgroundColor: AppColors.darkBackground,
      textTheme: _buildTextTheme(textColor: Colors.white),
      cardTheme: _buildCardTheme(cardColor: AppColors.darkSurface),
      elevatedButtonTheme: _buildElevatedButtonTheme(),
      appBarTheme: _buildAppBarTheme(
        backgroundColor: AppColors.onPrimaryContainer,
        foregroundColor: Colors.white,
      ),
      brightness: Brightness.dark,
      useMaterial3: true,
    );
  }
}
