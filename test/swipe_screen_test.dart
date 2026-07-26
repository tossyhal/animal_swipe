// test/swipe_screen_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:animal_swipe/screens/swipe_screen.dart';
import 'package:animal_swipe/models/animal_model.dart';
import 'package:animal_swipe/providers/animal_providers.dart';
import 'package:animal_swipe/services/prefs_service.dart';
import 'package:animal_swipe/screens/start_screen.dart';
import 'package:animal_swipe/widgets/swipe_card.dart';
import 'package:animal_swipe/constants/app_strings.dart';
import 'package:shared_preferences/shared_preferences.dart';

// テスト用の FakeSharedPreferences の簡易実装
class FakeSharedPreferences implements SharedPreferences {
  final Map<String, Object> _data = {};

  @override
  List<String>? getStringList(String key) => _data[key] as List<String>?;

  @override
  Future<bool> setStringList(String key, List<String> value) async {
    _data[key] = value;
    return true;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeAnimalImagesNotifier extends AnimalImagesNotifier {
  final List<AnimalImage> _initialImages;
  int _loadMoreCallCount = 0;
  bool _shouldSimulateError = false;

  FakeAnimalImagesNotifier(this._initialImages);

  /// 実装側の [build] は apiServiceProvider / selectedAnimalTypesProvider を
  /// watch するが、Fake では外部依存を持たず初期リストをそのまま返す
  @override
  Future<List<AnimalImage>> build() async {
    if (_shouldSimulateError) throw Exception('Failed to load images');
    return _initialImages;
  }

  @override
  Future<void> reload() async {
    if (_shouldSimulateError) {
      state = AsyncValue.error(
        Exception('Failed to load images'),
        StackTrace.current,
      );
      return;
    }
    state = AsyncValue.data(_initialImages);
  }

  @override
  void removeTopImage() {
    final current = state.value ?? const <AnimalImage>[];
    if (current.isEmpty) return;

    final rest = current.sublist(1);
    // 画像の残りが閾値未満の場合、追加画像を読み込む
    if (rest.length < 3) {
      _loadMoreCallCount++; // カウンターをインクリメント
      state = AsyncValue.data([...rest, _additionalImage()]);
    } else {
      state = AsyncValue.data(rest);
    }
  }

  @override
  Future<void> loadMoreImages() async {
    await Future<void>.delayed(const Duration(milliseconds: 100));
    if (_shouldSimulateError) throw Exception('Failed to load more images');

    _loadMoreCallCount++;
    final current = state.value ?? const <AnimalImage>[];
    state = AsyncValue.data([...current, _additionalImage()]);
  }

  AnimalImage _additionalImage() => AnimalImage(
    id: 'additional_$_loadMoreCallCount',
    url: 'http://example.com/additional_$_loadMoreCallCount.jpg',
    type: _loadMoreCallCount % 2 == 0 ? 'cat' : 'dog',
  );

  void setSimulateError(bool shouldError) {
    _shouldSimulateError = shouldError;
  }

  int get loadMoreCallCount => _loadMoreCallCount;
}

void main() {
  group('SwipeScreen ウィジェットテスト', () {
    late FakeAnimalImagesNotifier fakeNotifier;
    late ProviderContainer container;

    setUp(() {
      fakeNotifier = FakeAnimalImagesNotifier([
        AnimalImage(id: '1', url: 'http://example.com/cat.jpg', type: 'cat'),
      ]);
      container = ProviderContainer(
        overrides: [
          animalImagesProvider.overrideWith(() => fakeNotifier),
          // prefsServiceProvider のオーバーライドを追加
          prefsServiceProvider.overrideWithValue(
            PrefsService(FakeSharedPreferences()),
          ),
        ],
      );
    });

    tearDown(() {
      container.dispose();
    });

    group('UI表示テスト', () {
      testWidgets('アプリバーとホームボタンが正しく表示されること', (tester) async {
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const MaterialApp(home: SwipeScreen()),
          ),
        );

        // AppBarの確認
        expect(find.byType(AppBar), findsOneWidget);
        // ホームボタンの確認
        expect(find.byIcon(Icons.home), findsOneWidget);
        expect(find.text(AppStrings.homeButton), findsOneWidget);
      });

      testWidgets('画像がある場合、SwipeCardが表示されること', (tester) async {
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const MaterialApp(home: SwipeScreen()),
          ),
        );

        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        expect(find.byType(SwipeCard), findsOneWidget);
      });

      testWidgets('画像が空の場合、ローディングインジケータが表示されること', (tester) async {
        fakeNotifier = FakeAnimalImagesNotifier([]);
        container = ProviderContainer(
          overrides: [
            animalImagesProvider.overrideWith(() => fakeNotifier),
            prefsServiceProvider.overrideWithValue(
              PrefsService(FakeSharedPreferences()),
            ),
          ],
        );

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const MaterialApp(home: SwipeScreen()),
          ),
        );

        expect(find.byType(CircularProgressIndicator), findsOneWidget);
        expect(find.text(AppStrings.loading), findsOneWidget);
        expect(find.byType(SwipeCard), findsNothing);
      });
    });

    group('インタラクションテスト', () {
      testWidgets('アクションボタン（×）をタップすると次の画像が表示されること', (tester) async {
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const MaterialApp(home: SwipeScreen()),
          ),
        );

        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        // ×ボタンを探してタップ
        final closeButton = find.byIcon(Icons.close);
        expect(closeButton, findsOneWidget);
        await tester.tap(closeButton);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        // 画像が更新されたことを確認
        expect(fakeNotifier.loadMoreCallCount, greaterThan(0));
      });

      testWidgets('アクションボタン（ハート）をタップするとスナックバーが表示されること', (tester) async {
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const MaterialApp(home: SwipeScreen()),
          ),
        );

        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        // ハートボタンを探してタップ
        final heartButton = find.byIcon(Icons.favorite);
        expect(heartButton, findsOneWidget);
        await tester.tap(heartButton);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        // スナックバーが表示されることを確認
        expect(find.text(AppStrings.liked), findsOneWidget);
        // 画像が更新されたことを確認
        expect(fakeNotifier.loadMoreCallCount, greaterThan(0));
      });

      testWidgets('ホームに戻るボタンをタップするとStartScreenに遷移すること', (tester) async {
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const MaterialApp(home: SwipeScreen()),
          ),
        );

        // ホームに戻るボタンをタップ
        await tester.tap(find.text(AppStrings.homeButton));
        await tester.pumpAndSettle();

        // StartScreenに遷移したことを確認
        expect(find.byType(StartScreen), findsOneWidget);
      });
    });

    // SwipeCardウィジェットのテスト
    group('SwipeCardテスト', () {
      testWidgets('左スワイプで正しいコールバックが呼ばれること', (tester) async {
        bool onSwipeLeftCalled = false;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SwipeCard(
                image: AnimalImage(
                  id: '1',
                  url: 'http://example.com/cat.jpg',
                  type: 'cat',
                ),
                onSwipeLeft: () {
                  onSwipeLeftCalled = true;
                },
                onSwipeRight: () {},
              ),
            ),
          ),
        );

        // SwipeCardを左にスワイプ
        await tester.drag(find.byType(SwipeCard), const Offset(-400, 0));
        await tester.pumpAndSettle();

        // 左スワイプコールバックが呼ばれたことを確認
        expect(onSwipeLeftCalled, true);
      });

      testWidgets('右スワイプで正しいコールバックが呼ばれること', (tester) async {
        bool onSwipeRightCalled = false;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SwipeCard(
                image: AnimalImage(
                  id: '1',
                  url: 'http://example.com/cat.jpg',
                  type: 'cat',
                ),
                onSwipeLeft: () {},
                onSwipeRight: () {
                  onSwipeRightCalled = true;
                },
              ),
            ),
          ),
        );

        // SwipeCardを右にスワイプ
        await tester.drag(find.byType(SwipeCard), const Offset(400, 0));
        await tester.pumpAndSettle();

        // 右スワイプコールバックが呼ばれたことを確認
        expect(onSwipeRightCalled, true);
      });
    });

    group('エラーハンドリングテスト', () {
      testWidgets('画像が空の場合のアクションボタン無効化テスト', (tester) async {
        fakeNotifier = FakeAnimalImagesNotifier([]);
        container = ProviderContainer(
          overrides: [
            animalImagesProvider.overrideWith(() => fakeNotifier),
            prefsServiceProvider.overrideWithValue(
              PrefsService(FakeSharedPreferences()),
            ),
          ],
        );

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const MaterialApp(home: SwipeScreen()),
          ),
        );

        // アクションボタンをタップしても反応しないことを確認（無効化されている）
        await tester.tap(find.byIcon(Icons.close));
        await tester.pump();
        expect(fakeNotifier.loadMoreCallCount, 0);

        await tester.tap(find.byIcon(Icons.favorite));
        await tester.pump();
        expect(fakeNotifier.loadMoreCallCount, 0);
      });
    });
  });
}
