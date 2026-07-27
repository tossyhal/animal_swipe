// test/settings_screen_test.dart
import 'package:animal_swipe/constants/app_strings.dart';
import 'package:animal_swipe/providers/theme_mode_provider.dart';
import 'package:animal_swipe/screens/settings_screen.dart';
import 'package:animal_swipe/screens/start_screen.dart';
import 'package:animal_swipe/services/prefs_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SettingsScreen ウィジェットテスト', () {
    late SharedPreferences prefs;
    late ProviderContainer container;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
      container = ProviderContainer(
        overrides: [
          prefsServiceProvider.overrideWithValue(PrefsService(prefs)),
        ],
      );
    });

    tearDown(() => container.dispose());

    testWidgets('ライト／ダーク／システムの3択が表示されること', (tester) async {
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: SettingsScreen()),
        ),
      );

      expect(find.text(AppStrings.themeModeLight), findsOneWidget);
      expect(find.text(AppStrings.themeModeDark), findsOneWidget);
      expect(find.text(AppStrings.themeModeSystem), findsOneWidget);
    });

    testWidgets('既定ではシステム設定に合わせるが選択されていること', (tester) async {
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: SettingsScreen()),
        ),
      );

      expect(container.read(themeModeProvider), ThemeMode.system);
    });

    testWidgets('ダークを選ぶとテーマモードが更新され永続化されること', (tester) async {
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: SettingsScreen()),
        ),
      );

      await tester.tap(find.text(AppStrings.themeModeDark));
      await tester.pump();

      expect(container.read(themeModeProvider), ThemeMode.dark);
      expect(prefs.getString('theme_mode'), 'dark');
    });
  });

  group('StartScreen からの設定画面導線', () {
    late ProviderContainer container;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      container = ProviderContainer(
        overrides: [
          prefsServiceProvider.overrideWithValue(PrefsService(prefs)),
        ],
      );
    });

    tearDown(() => container.dispose());

    testWidgets('設定アイコンをタップするとSettingsScreenに遷移すること', (tester) async {
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: StartScreen()),
        ),
      );

      await tester.tap(find.byIcon(Icons.settings_outlined));
      await tester.pumpAndSettle();

      expect(find.byType(SettingsScreen), findsOneWidget);
    });
  });
}
