import 'package:flutter/material.dart';

/// アプリ全体で使用するブランドカラー定数
///
/// ここに置くのは「シード色」と「M3 の派生では表現できないアクセント色」だけ。
/// `primaryContainer` / `surface` 系などのトーナルパレットは
/// [ColorScheme.fromSeed] が [primary] から生成するため、手書きしない。
class AppColors {
  AppColors._();

  /// ColorScheme のシード色
  static const Color primary = Color(0xFF557C64);

  // Accent Colors（ブランド指定色。fromSeed の派生を上書きする）
  static const Color secondary = Color(0xFFF09A76);
  static const Color tertiary = Color(0xFFF8CFAE);
  static const Color error = Color(0xFFD95D50);

  // 前景色の候補ペア（AppTheme.onColorFor が使用）
  static const Color canvas = Color(0xFFF8F5EF);
  static const Color ink = Color(0xFF233129);
}
