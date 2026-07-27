// test/swipe_screen_test.dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:animal_swipe/screens/swipe_screen.dart';
import 'package:animal_swipe/models/animal_model.dart';
import 'package:animal_swipe/models/animal_type.dart';
import 'package:animal_swipe/services/api_service.dart';
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
  bool removeTopImage({int? deckToken}) {
    final current = state.value ?? const <AnimalImage>[];
    if (current.isEmpty) return false;
    if (deckToken != null && deckToken != deckGeneration) return false;

    final rest = current.sublist(1);
    // 画像の残りが閾値未満の場合、追加画像を読み込む
    if (rest.length < 3) {
      _loadMoreCallCount++; // カウンターをインクリメント
      state = AsyncValue.data([...rest, _additionalImage()]);
    } else {
      state = AsyncValue.data(rest);
    }
    return true;
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
    type: _loadMoreCallCount % 2 == 0 ? AnimalType.cat : AnimalType.dog,
  );

  void setSimulateError(bool shouldError) {
    _shouldSimulateError = shouldError;
  }

  int get loadMoreCallCount => _loadMoreCallCount;
}

/// 応答を任意のタイミングまで保留できる ApiService
class _DeferredApiService implements IApiService {
  final _pending = <Completer<List<AnimalImage>>>[];

  @override
  Future<List<AnimalImage>> fetchImages(List<AnimalType> types) {
    final completer = Completer<List<AnimalImage>>();
    _pending.add(completer);
    return completer.future;
  }

  void completeFirstWith(List<AnimalType> types) {
    _pending.removeAt(0).complete([
      for (final type in types)
        AnimalImage(
          id: type.id,
          url: 'http://example.com/${type.id}.jpg',
          type: type,
        ),
    ]);
  }
}

void main() {
  group('SwipeScreen ウィジェットテスト', () {
    late FakeAnimalImagesNotifier fakeNotifier;
    late ProviderContainer container;

    setUp(() {
      fakeNotifier = FakeAnimalImagesNotifier([
        const AnimalImage(
          id: '1',
          url: 'http://example.com/cat.jpg',
          type: AnimalType.cat,
        ),
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

    group('カードスタックテスト（#6）', () {
      testWidgets('山札が3枚を超えても先頭3枚だけがスタックとして描画されること', (tester) async {
        fakeNotifier = FakeAnimalImagesNotifier([
          for (var i = 0; i < 5; i++)
            AnimalImage(
              id: '$i',
              url: 'http://example.com/$i.jpg',
              type: AnimalType.cat,
            ),
        ]);
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
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        // 山札は5枚あるが、スタックに乗るのは先頭3枚だけ
        expect(find.byType(SwipeCard), findsNWidgets(3));
      });

      testWidgets('先頭以外のカードはIgnorePointerでジェスチャを受けないこと', (tester) async {
        final images = [
          for (var i = 0; i < 3; i++)
            AnimalImage(
              id: '$i',
              url: 'http://example.com/$i.jpg',
              type: AnimalType.cat,
            ),
        ];
        fakeNotifier = FakeAnimalImagesNotifier(images);
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
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        // 2枚目・3枚目は IgnorePointer(ignoring: true) の配下にあり、
        // ジェスチャを受けない。Flutter フレームワーク自体も他の目的で
        // IgnorePointer を使うことがあるため、「ignoring:true を持つものが
        // 祖先に少なくとも1つある」ことを確認する
        for (var i = 1; i < 3; i++) {
          final cardFinder = find.byKey(ObjectKey(images[i]));
          expect(cardFinder, findsOneWidget);
          final ancestors = tester.widgetList<IgnorePointer>(
            find.ancestor(of: cardFinder, matching: find.byType(IgnorePointer)),
          );
          expect(
            ancestors.any((widget) => widget.ignoring),
            isTrue,
            reason: '$i枚目はジェスチャを遮る IgnorePointer 配下にあるべき',
          );
        }

        // 先頭カードは、祖先の IgnorePointer がどれも ignoring:false
        // （＝実際には操作を遮っていない）こと
        final topCardFinder = find.byKey(ObjectKey(images.first));
        final topAncestors = tester.widgetList<IgnorePointer>(
          find.ancestor(
            of: topCardFinder,
            matching: find.byType(IgnorePointer),
          ),
        );
        expect(
          topAncestors.any((widget) => widget.ignoring),
          isFalse,
          reason: '先頭カードはどの祖先からもジェスチャを遮られていない',
        );
      });

      testWidgets('先頭以外のカードは読み上げ対象から除外されること', (tester) async {
        final images = [
          for (var i = 0; i < 3; i++)
            AnimalImage(
              id: '$i',
              url: 'http://example.com/$i.jpg',
              type: AnimalType.cat,
            ),
        ];
        fakeNotifier = FakeAnimalImagesNotifier(images);
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
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        // IgnorePointer が外すのはポインタ関連のセマンティクスだけなので、
        // 背面カードのテキストはそれだけでは読み上げ対象に残ってしまう。
        // ExcludeSemantics で明示的に除外していることを確認する。
        for (var i = 1; i < 3; i++) {
          final cardFinder = find.byKey(ObjectKey(images[i]));
          expect(cardFinder, findsOneWidget);
          expect(
            find.ancestor(
              of: cardFinder,
              matching: find.byType(ExcludeSemantics),
            ),
            findsWidgets,
            reason: '$i枚目は ExcludeSemantics 配下にあるべき',
          );
        }

        // 先頭カードは読み上げ対象に残っている
        final topAncestors = tester.widgetList<ExcludeSemantics>(
          find.ancestor(
            of: find.byKey(ObjectKey(images.first)),
            matching: find.byType(ExcludeSemantics),
          ),
        );
        expect(
          topAncestors.any((widget) => widget.excluding),
          isFalse,
          reason: '先頭カードは読み上げ対象から外れてはいけない',
        );
      });

      testWidgets('URL が重複していても山札の順序どおりに3枚描画されること', (tester) async {
        // ランダム画像 API は同じ URL を連続して返し得る。
        // ここで重複を間引くと「次に出るカード」の予告が実際の山札と
        // ずれる（[A, A, B] を [A, B] と描くと、1 回スワイプした後に
        // B ではなく A が出てきて予告が嘘になる）。
        final images = [
          const AnimalImage(
            id: 'a1',
            url: 'http://example.com/same.jpg',
            type: AnimalType.cat,
          ),
          const AnimalImage(
            id: 'a2',
            url: 'http://example.com/same.jpg',
            type: AnimalType.cat,
          ),
          const AnimalImage(
            id: 'b',
            url: 'http://example.com/other.jpg',
            type: AnimalType.cat,
          ),
        ];
        fakeNotifier = FakeAnimalImagesNotifier(images);
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
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        // 間引かれていれば 2 枚しか出ない
        expect(tester.takeException(), isNull);
        expect(find.byType(SwipeCard), findsNWidgets(3));

        // ObjectKey は identical 比較なので、URL と値が同じでも
        // 山札の各要素が別のキーとして扱われる
        for (final image in images) {
          expect(
            find.byKey(ObjectKey(image)),
            findsOneWidget,
            reason: '${image.id} が描画されていない',
          );
        }
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
                image: const AnimalImage(
                  id: '1',
                  url: 'http://example.com/cat.jpg',
                  type: AnimalType.cat,
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
                image: const AnimalImage(
                  id: '1',
                  url: 'http://example.com/cat.jpg',
                  type: AnimalType.cat,
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

    // Fake ではなく実装の Notifier を使い、Riverpod が前回値を保持したまま
    // AsyncLoading にする「再取得中」の状態を実際に発生させる
    group('再取得中の挙動（実 Provider）', () {
      testWidgets('再取得中は前回の値が残っていてもアクションボタンが無効になること', (tester) async {
        SharedPreferences.setMockInitialValues({
          'selected_animal_types': ['cat', 'dog'],
        });
        final prefs = PrefsService(await SharedPreferences.getInstance());
        final api = _DeferredApiService();
        final realContainer = ProviderContainer(
          overrides: [
            prefsServiceProvider.overrideWithValue(prefs),
            apiServiceProvider.overrideWithValue(api),
          ],
        );
        addTearDown(realContainer.dispose);

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: realContainer,
            child: const MaterialApp(home: SwipeScreen()),
          ),
        );

        // 初回取得を完了させる
        api.completeFirstWith([AnimalType.cat, AnimalType.dog]);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        // 山札は2枚（cat, dog）で、どちらもスタックに乗る
        expect(find.byType(SwipeCard), findsNWidgets(2));

        InkWell skipButton() => tester.widget<InkWell>(
          find.ancestor(
            of: find.byIcon(Icons.close),
            matching: find.byType(InkWell),
          ),
        );

        expect(skipButton().onTap, isNotNull, reason: 'カード表示中は操作できる');

        // カードスタック化（#6）前は、選択変更後も AnimatedSwitcher が
        // 退場中の古いカードを 250ms 保持し続けたため、その間にスワイプが
        // 飛んで来ないかをウィジェットレベルで確認していた。
        // スタック化後は古いカードが即座にツリーから外れるため、その
        // タイミング依存のシナリオ自体が発生しない。
        //
        // 本質的に守りたい不変条件は「表示時点の deckToken と異なる
        // 山札に対する操作は無視される」ことなので、それを Notifier に
        // 対して直接確認する。
        final staleToken = realContainer
            .read(animalImagesProvider.notifier)
            .deckGeneration;

        // 選択を変更 → provider が再 build され、前回値を保持したまま
        // AsyncLoading になる（山札の世代も入れ替わる）
        realContainer
            .read(selectedAnimalTypesProvider.notifier)
            .selectType(AnimalType.dog, false);
        await tester.pump();

        // ボタンの無効化はフレーム単位で即座に反映される
        expect(skipButton().onTap, isNull, reason: '再取得中に古い山札へ操作できてはいけない');

        // 古い deckToken での操作は「その山札はもう表示されていない」ため
        // 何も取り除かず false を返す。再取得中の state を壊してもいけない。
        final removed = realContainer
            .read(animalImagesProvider.notifier)
            .removeTopImage(deckToken: staleToken);
        expect(removed, isFalse, reason: '古い山札への操作は無視される');
        expect(
          realContainer.read(animalImagesProvider).isLoading,
          isTrue,
          reason: '古い操作で再取得中状態が壊されないこと',
        );

        // 再取得が終わっていない間は、カードスタックではなくローディング表示
        expect(find.byType(SwipeCard), findsNothing, reason: 'ローディング表示に変わる');
        expect(find.text(AppStrings.loading), findsOneWidget);
      });
    });
  });
}
