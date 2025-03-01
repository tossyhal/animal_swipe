// test/swipe_screen_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:animal_swipe/screens/swipe_screen.dart';
import 'package:animal_swipe/models/animal_model.dart';
import 'package:animal_swipe/providers/animal_providers.dart';
import 'package:animal_swipe/services/api_service.dart';

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
      testWidgets('アプリバーが正しく表示されること', (tester) async {
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const MaterialApp(home: SwipeScreen()),
          ),
        );

        // AppBarとペットアイコンの確認
        expect(find.byType(AppBar), findsOneWidget);
        expect(find.byIcon(Icons.pets), findsOneWidget);
        // タイトルテキストの確認
        expect(find.text('動物たちとの癒しのひととき'), findsOneWidget);
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
        expect(find.byType(Card), findsWidgets);
        expect(find.byType(Image), findsWidgets);
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
        expect(find.byType(Card), findsNothing);
      });
    });

    group('インタラクションテスト', () {
      testWidgets('右スワイプで次の画像が表示されること', (tester) async {
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const MaterialApp(home: SwipeScreen()),
          ),
        );

        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        // 最初のカードを記録
        final firstCard = find.byType(Card).first;

        // 右にスワイプ
        await tester.drag(firstCard, const Offset(500, 0));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        // 新しい画像が読み込まれたことを確認
        expect(fakeNotifier.loadMoreCallCount, 1);
      });

      testWidgets('左スワイプで次の画像が表示されること', (tester) async {
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const MaterialApp(home: SwipeScreen()),
          ),
        );

        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        final firstCard = find.byType(Card).first;

        // 左にスワイプ
        await tester.drag(firstCard, const Offset(-500, 0));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        // 新しい画像が読み込まれたことを確認
        expect(fakeNotifier.loadMoreCallCount, 1);
      });
    });

    group('エラーハンドリングテスト', () {
      testWidgets('画像読み込みエラー時にエラーメッセージが表示されること', (tester) async {
        fakeNotifier.setSimulateError(true);

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const MaterialApp(home: SwipeScreen()),
          ),
        );

        // エラー発生とエラーメッセージの表示を待つ
        await tester.pump();
        for (int i = 0; i < 5; i++) {
          await tester.pump(const Duration(milliseconds: 100));
        }

        // エラー表示を確認
        expect(find.text('画像の読み込みに失敗しました'), findsOneWidget);
      });

      testWidgets('追加画像読み込みエラー時にエラーメッセージが表示されること', (tester) async {
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const MaterialApp(home: SwipeScreen()),
          ),
        );

        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        // エラーをシミュレート
        fakeNotifier.setSimulateError(true);

        // スワイプしてエラーを発生させる
        await tester.drag(find.byType(Card).first, const Offset(500, 0));
        // アニメーションの完了を待つ
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        // エラー表示を確認
        expect(find.byIcon(Icons.error_outline), findsOneWidget);
        expect(find.text('画像の読み込みに失敗しました'), findsOneWidget);
      });
    });
  });
}
