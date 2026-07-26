// test/app_initial_screen_test.dart
import 'dart:async';

import 'package:animal_swipe/main.dart';
import 'package:animal_swipe/models/animal_model.dart';
import 'package:animal_swipe/screens/start_screen.dart';
import 'package:animal_swipe/screens/swipe_screen.dart';
import 'package:animal_swipe/services/api_service.dart';
import 'package:animal_swipe/services/prefs_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 応答を返さない ApiService。
/// 初期画面の判定だけを見たいので、通信は保留したままにする。
class _NeverCompletingApiService implements IApiService {
  @override
  Future<List<AnimalImage>> fetchImages(List<String> types) =>
      Completer<List<AnimalImage>>().future;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /// 保存済みの選択タイプを与えてアプリを起動する
  Future<void> pumpApp(WidgetTester tester, List<String> savedTypes) async {
    SharedPreferences.setMockInitialValues({
      'selected_animal_types': savedTypes,
    });
    final prefsService = PrefsService(await SharedPreferences.getInstance());

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          prefsServiceProvider.overrideWithValue(prefsService),
          apiServiceProvider.overrideWithValue(_NeverCompletingApiService()),
        ],
        child: const AnimalSwipeApp(),
      ),
    );
  }

  group('起動時の初期画面', () {
    testWidgets('前回の選択がなければ StartScreen から始まる', (tester) async {
      await pumpApp(tester, []);

      expect(find.byType(StartScreen), findsOneWidget);
      expect(find.byType(SwipeScreen), findsNothing);
    });

    testWidgets('前回の選択があれば SwipeScreen へ直行する', (tester) async {
      await pumpApp(tester, ['cat', 'dog']);

      expect(find.byType(SwipeScreen), findsOneWidget);
      expect(find.byType(StartScreen), findsNothing);
    });

    testWidgets('直行した場合でも「選び直す」から StartScreen に戻れる', (tester) async {
      await pumpApp(tester, ['cat']);
      expect(find.byType(SwipeScreen), findsOneWidget);

      await tester.tap(find.byIcon(Icons.home));
      await tester.pumpAndSettle();

      expect(
        find.byType(StartScreen),
        findsOneWidget,
        reason: '直行しても選択をやり直す導線が残っていること',
      );
    });
  });
}
