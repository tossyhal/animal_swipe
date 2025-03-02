// test/swipe_screen_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:animal_swipe/screens/swipe_screen.dart';
import 'package:animal_swipe/models/animal_model.dart';
import 'package:animal_swipe/providers/animal_providers.dart';
import 'package:animal_swipe/services/api_service.dart';
import 'package:animal_swipe/screens/start_screen.dart';
import 'package:animal_swipe/widgets/swipe_card.dart';

class FakeAnimalImagesNotifier extends AnimalImagesNotifier {
  final List<AnimalImage> _initialImages;
  int _loadMoreCallCount = 0;
  bool _shouldSimulateError = false;

  FakeAnimalImagesNotifier(this._initialImages)
    : super(FakeApiService(), ['cat', 'dog']) {
    state = _initialImages;
  }

  bool _mounted = true;

  @override
  bool get mounted => _mounted;

  @override
  void dispose() {
    _mounted = false;
    super.dispose();
  }

  @override
  Future<void> loadInitialImages() async {
    if (!mounted) return;

    if (_shouldSimulateError) {
      state = [];
      if (!mounted) return;
      throw Exception('Failed to load images');
    }

    if (!mounted) return;
    state = _initialImages;
  }

  @override
  void removeTopImage() {
    if (state.isNotEmpty) {
      state = state.sublist(1);
      // 画像の残りが閾値未満の場合、追加画像を読み込む
      if (state.length < 3) {
        _loadMoreCallCount++; // カウンターをインクリメント
        state = [
          ...state,
          AnimalImage(
            id: 'additional_$_loadMoreCallCount',
            url: 'http://example.com/additional_$_loadMoreCallCount.jpg',
            type: _loadMoreCallCount % 2 == 0 ? 'cat' : 'dog',
          ),
        ];
      }
    }
  }

  @override
  Future<void> loadMoreImages() async {
    if (_shouldSimulateError) {
      await Future<void>.delayed(const Duration(milliseconds: 100));
      throw Exception('Failed to load more images');
    }
    await Future<void>.delayed(const Duration(milliseconds: 100));
    _loadMoreCallCount++;
    state = [
      ...state,
      AnimalImage(
        id: 'additional_$_loadMoreCallCount',
        url: 'http://example.com/additional_$_loadMoreCallCount.jpg',
        type: _loadMoreCallCount % 2 == 0 ? 'cat' : 'dog',
      ),
    ];
  }

  void setSimulateError(bool shouldError) {
    _shouldSimulateError = shouldError;
  }

  int get loadMoreCallCount => _loadMoreCallCount;
}

class FakeApiService implements IApiService {
  @override
  Future<List<AnimalImage>> fetchImages(List<String> types) async {
    return [];
  }
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
        overrides: [animalImagesProvider.overrideWith((_) => fakeNotifier)],
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
        expect(find.text('ホームに戻る'), findsOneWidget);
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
          overrides: [animalImagesProvider.overrideWith((_) => fakeNotifier)],
        );

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const MaterialApp(home: SwipeScreen()),
          ),
        );

        expect(find.byType(CircularProgressIndicator), findsOneWidget);
        expect(find.text('読み込み中...'), findsOneWidget);
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
        expect(find.text('お気に入り機能は近日実装予定です'), findsOneWidget);
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
        await tester.tap(find.text('ホームに戻る'));
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
        await tester.drag(find.byType(SwipeCard), const Offset(-300, 0));
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
        await tester.drag(find.byType(SwipeCard), const Offset(300, 0));
        await tester.pumpAndSettle();

        // 右スワイプコールバックが呼ばれたことを確認
        expect(onSwipeRightCalled, true);
      });
    });

    group('エラーハンドリングテスト', () {
      testWidgets('画像が空の場合のアクションボタン無効化テスト', (tester) async {
        fakeNotifier = FakeAnimalImagesNotifier([]);
        container = ProviderContainer(
          overrides: [animalImagesProvider.overrideWith((_) => fakeNotifier)],
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
