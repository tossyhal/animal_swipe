// test/start_screen_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:animal_swipe/screens/start_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:animal_swipe/services/prefs_service.dart';
import 'package:animal_swipe/screens/swipe_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('StartScreen ウィジェットテスト', () {
    late SharedPreferences prefs;
    late PrefsService prefsService;
    late ProviderContainer container;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
      prefsService = PrefsService(prefs);
      container = ProviderContainer(
        overrides: [prefsServiceProvider.overrideWithValue(prefsService)],
      );
    });

    tearDown(() {
      container.dispose();
    });

    group('UI表示テスト', () {
      testWidgets('アプリタイトルが正しく表示されること', (tester) async {
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const MaterialApp(home: StartScreen()),
          ),
        );

        expect(find.text('Animal Swipe'), findsOneWidget);
      });

      testWidgets('全ての動物タイプが表示されること', (tester) async {
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const MaterialApp(home: StartScreen()),
          ),
        );

        expect(find.text('ねこ'), findsOneWidget);
        expect(find.text('いぬ'), findsOneWidget);
        expect(find.text('はじめる'), findsOneWidget);
      });

      testWidgets('初期状態では「はじめる」ボタンが無効であること', (tester) async {
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const MaterialApp(home: StartScreen()),
          ),
        );

        final button = tester.widget<ElevatedButton>(
          find.byType(ElevatedButton),
        );
        expect(button.onPressed, isNull, reason: '動物が選択されていない場合、ボタンは無効');
      });
    });

    group('インタラクションテスト', () {
      testWidgets('動物タイプを選択すると「はじめる」ボタンが有効になること', (tester) async {
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const MaterialApp(home: StartScreen()),
          ),
        );

        // ねこを選択
        await tester.tap(find.text('ねこ'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        final button = tester.widget<ElevatedButton>(
          find.byType(ElevatedButton),
        );
        expect(button.onPressed, isNotNull, reason: '動物が選択されている場合、ボタンは有効');
      });

      testWidgets('複数の動物タイプを選択できること', (tester) async {
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const MaterialApp(home: StartScreen()),
          ),
        );

        // ねこといぬを選択
        await tester.tap(find.text('ねこ'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        await tester.tap(find.text('いぬ'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        // 両方のタイルに選択マークが表示されていることを確認
        expect(
          find.descendant(
            of: find.ancestor(
              of: find.text('ねこ'),
              matching: find.byType(InkWell),
            ),
            matching: find.byIcon(Icons.check),
          ),
          findsOneWidget,
          reason: 'ねこのタイルに選択マークが表示されていること',
        );

        expect(
          find.descendant(
            of: find.ancestor(
              of: find.text('いぬ'),
              matching: find.byType(InkWell),
            ),
            matching: find.byIcon(Icons.check),
          ),
          findsOneWidget,
          reason: 'いぬのタイルに選択マークが表示されていること',
        );
      });

      testWidgets('選択を解除できること', (tester) async {
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const MaterialApp(home: StartScreen()),
          ),
        );

        // ねこを選択して解除
        await tester.tap(find.text('ねこ'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        await tester.tap(find.text('ねこ'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        // 選択マークが表示されていないことを確認
        expect(
          find.descendant(
            of: find.ancestor(
              of: find.text('ねこ'),
              matching: find.byType(InkWell),
            ),
            matching: find.byIcon(Icons.check),
          ),
          findsNothing,
          reason: 'ねこのタイルから選択マークが消えていること',
        );

        // ボタンが無効化されることを確認
        final button = tester.widget<ElevatedButton>(
          find.byType(ElevatedButton),
        );
        expect(button.onPressed, isNull);
      });

      testWidgets('「はじめる」ボタンタップでSwipeScreenに遷移すること', (tester) async {
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const MaterialApp(home: StartScreen()),
          ),
        );

        // ねこを選択
        await tester.tap(find.text('ねこ'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        // はじめるボタンをタップ
        await tester.tap(find.text('はじめる'));
        await tester.pump();
        await tester.pump(
          const Duration(milliseconds: 500),
        ); // 遷移アニメーションのため、少し長めに

        // 画面遷移の確認
        expect(find.byType(StartScreen), findsNothing);
        expect(
          find.byType(SwipeScreen),
          findsOneWidget,
          reason: 'SwipeScreenに遷移すること',
        );
      });
    });

    group('永続化テスト', () {
      testWidgets('選択した動物タイプが保存されること', (tester) async {
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const MaterialApp(home: StartScreen()),
          ),
        );

        // ねこといぬを選択
        await tester.tap(find.text('ねこ'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        await tester.tap(find.text('いぬ'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        // SharedPreferencesに保存されていることを確認
        final savedTypes = prefs.getStringList('selected_animal_types');
        expect(
          savedTypes,
          containsAll(['cat', 'dog']),
          reason: '選択した動物タイプが保存されていること',
        );
      });

      testWidgets('保存された選択状態が復元されること', (tester) async {
        // 事前に選択状態を保存
        await prefs.setStringList('selected_animal_types', ['cat', 'dog']);

        // 画面を再構築
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const MaterialApp(home: StartScreen()),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        // 選択マークが表示されていることを確認
        expect(
          find.descendant(
            of: find.ancestor(
              of: find.text('ねこ'),
              matching: find.byType(InkWell),
            ),
            matching: find.byIcon(Icons.check),
          ),
          findsOneWidget,
          reason: '保存されたねこの選択状態が復元されること',
        );

        expect(
          find.descendant(
            of: find.ancestor(
              of: find.text('いぬ'),
              matching: find.byType(InkWell),
            ),
            matching: find.byIcon(Icons.check),
          ),
          findsOneWidget,
          reason: '保存されたいぬの選択状態が復元されること',
        );
      });
    });
  });
}
