// test/app_theme_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:animal_swipe/constants/app_colors.dart';
import 'package:animal_swipe/constants/app_strings.dart';
import 'package:animal_swipe/models/animal_model.dart';
import 'package:animal_swipe/providers/animal_providers.dart';
import 'package:animal_swipe/screens/start_screen.dart';
import 'package:animal_swipe/screens/swipe_screen.dart';
import 'package:animal_swipe/services/prefs_service.dart';
import 'package:animal_swipe/theme/app_theme.dart';

/// WCAG のコントラスト比
double _contrast(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  final lighter = la > lb ? la : lb;
  final darker = la > lb ? lb : la;
  return (lighter + 0.05) / (darker + 0.05);
}

class _FakeImagesNotifier extends AnimalImagesNotifier {
  @override
  Future<List<AnimalImage>> build() async => [
    AnimalImage(id: '1', url: 'http://example.com/cat.jpg', type: 'cat'),
  ];
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final light = AppTheme.lightTheme();
  final dark = AppTheme.darkTheme();

  group('ColorScheme の整合性', () {
    test('ライト／ダークの brightness が正しいこと', () {
      expect(light.colorScheme.brightness, Brightness.light);
      expect(dark.colorScheme.brightness, Brightness.dark);
    });

    test('ブランドのアクセント色がそのまま反映されること', () {
      for (final scheme in [light.colorScheme, dark.colorScheme]) {
        expect(scheme.secondary, AppColors.secondary);
        expect(scheme.tertiary, AppColors.tertiary);
        expect(scheme.error, AppColors.error);
      }
    });

    test('本文向けロールが WCAG AA（4.5:1）を満たすこと', () {
      for (final entry in {'light': light, 'dark': dark}.entries) {
        final scheme = entry.value.colorScheme;
        expect(
          _contrast(scheme.primary, scheme.onPrimary),
          greaterThanOrEqualTo(4.5),
          reason: '${entry.key}: primary / onPrimary のコントラスト不足',
        );
        expect(
          _contrast(scheme.surface, scheme.onSurface),
          greaterThanOrEqualTo(4.5),
          reason: '${entry.key}: surface / onSurface のコントラスト不足',
        );
        expect(
          _contrast(scheme.primaryContainer, scheme.onPrimaryContainer),
          greaterThanOrEqualTo(4.5),
          reason:
              '${entry.key}: primaryContainer / onPrimaryContainer のコントラスト不足',
        );
      }
    });

    // secondary / tertiary / error はブランド指定色のため 4.5:1 には届かない。
    // これらの on 色はアイコンなど大きめのグラフィックにしか使わないので、
    // WCAG の非テキスト基準 3:1 を下限とする。
    test('アクセント色の on 色が非テキスト基準（3:1）を満たすこと', () {
      for (final entry in {'light': light, 'dark': dark}.entries) {
        final scheme = entry.value.colorScheme;
        expect(
          _contrast(scheme.secondary, scheme.onSecondary),
          greaterThanOrEqualTo(3.0),
          reason: '${entry.key}: secondary / onSecondary のコントラスト不足',
        );
        expect(
          _contrast(scheme.tertiary, scheme.onTertiary),
          greaterThanOrEqualTo(3.0),
          reason: '${entry.key}: tertiary / onTertiary のコントラスト不足',
        );
        expect(
          _contrast(scheme.error, scheme.onError),
          greaterThanOrEqualTo(3.0),
          reason: '${entry.key}: error / onError のコントラスト不足',
        );
      }
    });

    test('ダークの primary がライトより明るいこと（暗い背景に沈まない）', () {
      expect(
        dark.colorScheme.primary.computeLuminance(),
        greaterThan(light.colorScheme.primary.computeLuminance()),
        reason: 'ダークで primary を濃い緑のまま固定すると背景に沈む',
      );
    });

    test('primaryContainer / onPrimaryContainer が手動で入れ替えられていないこと', () {
      // ライトはコンテナが明るく on が暗い。ダークはその逆になるのが M3 の並び。
      expect(
        light.colorScheme.primaryContainer.computeLuminance(),
        greaterThan(light.colorScheme.onPrimaryContainer.computeLuminance()),
      );
      expect(
        dark.colorScheme.primaryContainer.computeLuminance(),
        lessThan(dark.colorScheme.onPrimaryContainer.computeLuminance()),
      );
    });

    test('surface 系のトーンが単調に並んでいること', () {
      final l = light.colorScheme;
      expect(
        l.surfaceContainerLowest.computeLuminance(),
        greaterThan(l.surface.computeLuminance()),
      );
      expect(
        l.surface.computeLuminance(),
        greaterThan(l.surfaceContainerHighest.computeLuminance()),
      );

      final d = dark.colorScheme;
      expect(
        d.surfaceContainerLowest.computeLuminance(),
        lessThan(d.surface.computeLuminance()),
      );
      expect(
        d.surface.computeLuminance(),
        lessThan(d.surfaceContainerHighest.computeLuminance()),
      );
    });

    test('UI が参照するロールが surface と同じ色相帯にあること', () {
      // fromSeed 由来なので outlineVariant / onSurfaceVariant も
      // surface と同じトーナルパレットから生成される
      for (final scheme in [light.colorScheme, dark.colorScheme]) {
        expect(
          _contrast(scheme.surface, scheme.onSurfaceVariant),
          greaterThanOrEqualTo(3.0),
        );
        expect(
          _contrast(scheme.surface, scheme.outlineVariant),
          lessThan(3.0),
          reason: 'outlineVariant は控えめな境界線なので surface と近いトーンであるべき',
        );
      }
    });
  });

  group('fontFamily がテーマから一括で適用されること', () {
    test('ThemeData.textTheme の全ロールに fontFamily が入っていること', () {
      for (final entry in {'light': light, 'dark': dark}.entries) {
        final textTheme = entry.value.textTheme;
        final styles = <String, TextStyle?>{
          'displayLarge': textTheme.displayLarge,
          'titleLarge': textTheme.titleLarge,
          'titleMedium': textTheme.titleMedium,
          'bodyLarge': textTheme.bodyLarge,
          'bodyMedium': textTheme.bodyMedium,
          'bodySmall': textTheme.bodySmall,
          'labelLarge': textTheme.labelLarge,
        };
        styles.forEach((name, style) {
          expect(
            style?.fontFamily,
            AppStrings.fontFamily,
            reason: '${entry.key}: $name に fontFamily が適用されていない',
          );
        });
      }
    });

    test('AppBar のタイトルにも fontFamily が効いていること', () {
      for (final entry in {'light': light, 'dark': dark}.entries) {
        expect(
          entry.value.appBarTheme.titleTextStyle?.fontFamily,
          AppStrings.fontFamily,
          reason: '${entry.key}: AppBar のタイトルだけ既定フォントに落ちている',
        );
      }
    });

    testWidgets('画面上の Text が実際に fontFamily を解決できること', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final container = ProviderContainer(
        overrides: [
          prefsServiceProvider.overrideWithValue(PrefsService(prefs)),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(theme: light, home: const StartScreen()),
        ),
      );

      // 個別 TextStyle から fontFamily を消しても、
      // DefaultTextStyle 経由でテーマの書体が解決される
      final appName = tester.widget<Text>(find.text(AppStrings.appName));
      final resolved = DefaultTextStyle.of(
        tester.element(find.text(AppStrings.appName)),
      ).style.merge(appName.style);
      expect(resolved.fontFamily, AppStrings.fontFamily);
    });
  });

  group('ライト／ダーク両方で画面が描画できること', () {
    late ProviderContainer container;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      container = ProviderContainer(
        overrides: [
          prefsServiceProvider.overrideWithValue(PrefsService(prefs)),
          animalImagesProvider.overrideWith(_FakeImagesNotifier.new),
        ],
      );
    });

    tearDown(() => container.dispose());

    Future<void> pumpWithMode(
      WidgetTester tester,
      Widget home,
      ThemeMode mode,
    ) {
      return tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: AppTheme.lightTheme(),
            darkTheme: AppTheme.darkTheme(),
            themeMode: mode,
            home: home,
          ),
        ),
      );
    }

    for (final mode in [ThemeMode.light, ThemeMode.dark]) {
      testWidgets('StartScreen が $mode で例外なく描画されること', (tester) async {
        await pumpWithMode(tester, const StartScreen(), mode);
        await tester.pump();

        expect(tester.takeException(), isNull);
        expect(find.byType(StartScreen), findsOneWidget);
      });

      testWidgets('SwipeScreen が $mode で例外なく描画されること', (tester) async {
        await pumpWithMode(tester, const SwipeScreen(), mode);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(tester.takeException(), isNull);
        expect(find.byType(SwipeScreen), findsOneWidget);
      });
    }
  });
}
