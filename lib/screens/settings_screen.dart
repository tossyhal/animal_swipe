import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../constants/app_dimensions.dart';
import '../constants/app_strings.dart';
import '../providers/theme_mode_provider.dart';
import '../theme/theme_extensions.dart';

/// 設定画面
///
/// 現時点ではテーマ切り替えのみを提供する。
/// 将来的に好み学習のオン／オフ（#37）・通知（#41）・キャッシュ削除などを
/// 追加する受け皿として、セクション単位で並べられる構成にしてある。
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text(AppStrings.settingsTitle)),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.s20),
        children: const [_ThemeSection()],
      ),
    );
  }
}

/// テーマ（ライト／ダーク／システム）の切り替えセクション
class _ThemeSection extends ConsumerWidget {
  const _ThemeSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentMode = ref.watch(themeModeProvider);

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.s16,
          vertical: AppSpacing.s8,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(
                top: AppSpacing.s12,
                bottom: AppSpacing.s4,
              ),
              child: Text(
                AppStrings.themeSectionTitle,
                style: context.textTheme.titleMedium,
              ),
            ),
            Text(
              AppStrings.themeSectionDescription,
              style: context.textTheme.bodySmall?.copyWith(
                color: context.colors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppSpacing.s8),
            RadioGroup<ThemeMode>(
              groupValue: currentMode,
              onChanged: (value) {
                if (value == null) return;
                ref.read(themeModeProvider.notifier).setThemeMode(value);
              },
              child: Column(
                children: [
                  for (final mode in ThemeMode.values)
                    RadioListTile<ThemeMode>(
                      contentPadding: EdgeInsets.zero,
                      title: Text(_labelFor(mode)),
                      value: mode,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _labelFor(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return AppStrings.themeModeLight;
      case ThemeMode.dark:
        return AppStrings.themeModeDark;
      case ThemeMode.system:
        return AppStrings.themeModeSystem;
    }
  }
}
