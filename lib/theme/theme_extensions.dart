import 'package:flutter/material.dart';

/// BuildContextの拡張メソッド
/// テーマへのアクセスを簡略化
extension ThemeExtension on BuildContext {
  /// ColorSchemeへの簡易アクセス
  ColorScheme get colors => Theme.of(this).colorScheme;

  /// TextThemeへの簡易アクセス
  TextTheme get textTheme => Theme.of(this).textTheme;
}
