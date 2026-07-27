import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/prefs_service.dart';

/// アプリ全体のテーマモード（ライト／ダーク／システム）を管理するプロバイダー
final themeModeProvider = NotifierProvider<ThemeModeNotifier, ThemeMode>(
  ThemeModeNotifier.new,
);

/// テーマモードの [Notifier]
///
/// [SelectedAnimalTypesNotifier]（`animal_providers.dart`）と同じ形にしている。
/// `build()` は依存の変化で再実行され、その都度この場で再代入されるため
/// `late` のみで `final` にはしない。
class ThemeModeNotifier extends Notifier<ThemeMode> {
  late PrefsService _prefsService;

  @override
  ThemeMode build() {
    _prefsService = ref.watch(prefsServiceProvider);
    return _prefsService.getThemeMode();
  }

  /// テーマモードを更新し、ローカルに保存する
  void setThemeMode(ThemeMode mode) {
    if (state == mode) return;
    state = mode;
    _prefsService.saveThemeMode(mode);
  }
}
