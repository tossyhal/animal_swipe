// test/swipe_screen_test.dart
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:animal_swipe/screens/swipe_screen.dart';
import 'package:animal_swipe/models/animal_model.dart';
import 'package:animal_swipe/models/animal_type.dart';
import 'package:animal_swipe/services/api_service.dart';
import 'package:animal_swipe/providers/animal_providers.dart';
import 'package:animal_swipe/providers/favorites_provider.dart';
import 'package:animal_swipe/services/prefs_service.dart';
import 'package:animal_swipe/screens/favorites_screen.dart';
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
  String? getString(String key) => _data[key] as String?;

  @override
  Future<bool> setString(String key, String value) async {
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
  bool removeTopImage({
    int? deckToken,
    AnimalImage? expectedTop,
    bool undoRemovesFavorite = false,
  }) {
    final current = state.value ?? const <AnimalImage>[];
    if (current.isEmpty) return false;
    if (deckToken != null && deckToken != deckGeneration) return false;
    if (expectedTop != null && !identical(current.first, expectedTop)) {
      return false;
    }

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

/// [Image.network] のテストで実際にネットワークへ出ずに済ませるための
/// 最小の [HttpClient] フェイク。有効な 1x1 透明 PNG を常に返す。
///
/// 使うのは `getUrl` / `HttpClientRequest.headers` /
/// `HttpClientRequest.close` / `HttpClientResponse` の
/// `statusCode`・`contentLength`・`compressionState`・`listen` だけ
/// （[NetworkImage._loadAsync] が実際に触る範囲）なので、他のメンバーは
/// 未実装のまま `noSuchMethod` に委ねている。
class _FakeImageHttpClient implements HttpClient {
  /// 実際にリクエストされた URL の記録。
  ///
  /// 先読み（precacheImage）と表示（Image.network）の ImageProvider が
  /// 別キー扱いになっていないかは、ImageCache の中身を覗くよりも
  /// 「同じ URL に対して HTTP リクエストが何回飛んだか」を直接数えた方が
  /// Flutter 内部実装の詳細に依存せず確実（#7）。
  final List<Uri> requestedUrls = <Uri>[];

  @override
  Future<HttpClientRequest> getUrl(Uri url) async {
    requestedUrls.add(url);
    return _FakeImageHttpClientRequest();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeImageHttpClientRequest implements HttpClientRequest {
  @override
  final HttpHeaders headers = _FakeImageHttpHeaders();

  @override
  Future<HttpClientResponse> close() async => _FakeImageHttpClientResponse();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeImageHttpHeaders implements HttpHeaders {
  @override
  void add(String name, Object value, {bool preserveHeaderCase = false}) {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeImageHttpClientResponse implements HttpClientResponse {
  // 内容自体はテストの関心事ではないため、デコード可能な最小の PNG。
  static final Uint8List _bytes = base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk'
    '+A8AAQUBAScY42YAAAAASUVORK5CYII=',
  );

  @override
  int get statusCode => HttpStatus.ok;

  @override
  int get contentLength => _bytes.length;

  @override
  HttpClientResponseCompressionState get compressionState =>
      HttpClientResponseCompressionState.notCompressed;

  @override
  StreamSubscription<List<int>> listen(
    void Function(List<int> event)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) {
    return Stream<List<int>>.fromIterable(<List<int>>[_bytes]).listen(
      onData,
      onError: onError,
      onDone: onDone,
      cancelOnError: cancelOnError,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
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

    group('AppBar の可変幅対応（#8）', () {
      Future<void> pumpAt(
        WidgetTester tester,
        Size size, {
        double textScale = 1.0,
      }) async {
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              home: MediaQuery(
                data: MediaQueryData(
                  size: size,
                  textScaler: TextScaler.linear(textScale),
                ),
                child: const SwipeScreen(),
              ),
            ),
          ),
        );
        await tester.pump();
      }

      testWidgets('広い画面では「選び直す」がラベル付きで表示されること', (tester) async {
        await pumpAt(tester, const Size(600, 800));

        expect(find.text(AppStrings.homeButton), findsOneWidget);
        expect(tester.takeException(), isNull);
      });

      testWidgets('狭い画面では「選び直す」がアイコンだけに畳まれること', (tester) async {
        await pumpAt(tester, const Size(360, 640));

        // お気に入りアイコンが増えた分、ラベルを出すと横幅が足りず
        // タイトル行がオーバーフローする
        expect(find.text(AppStrings.homeButton), findsNothing);
        expect(find.byIcon(Icons.home), findsOneWidget);
        expect(tester.takeException(), isNull);
      });

      testWidgets('文字サイズを上げた場合も広い画面でラベルが畳まれること', (tester) async {
        // 論理幅は足りていても、文字倍率が上がるとラベルは長くなる
        await pumpAt(tester, const Size(500, 800), textScale: 2.0);

        expect(find.text(AppStrings.homeButton), findsNothing);
        expect(find.byIcon(Icons.home), findsOneWidget);
        expect(tester.takeException(), isNull);
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

      testWidgets('重複画像を含む山札でも Hero のタグ衝突で落ちないこと（#26）', (tester) async {
        // 同じ画像が同時にスタックへ並ぶと、id 由来の Hero タグが重複して
        // 「multiple heroes that share the same tag」で落ちていた。
        // Hero は遷移先が無く機能していなかったため削除済み。
        final images = [
          for (var i = 0; i < 3; i++)
            const AnimalImage(
              id: 'dup',
              url: 'http://example.com/dup.jpg',
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

        expect(tester.takeException(), isNull);
        expect(
          find.byType(Hero),
          findsNothing,
          reason: '機能していない Hero を再び持ち込まない',
        );

        // ルート遷移を開始しても Hero の重複アサーションを踏まない
        final navigator = tester.state<NavigatorState>(find.byType(Navigator));
        unawaited(
          navigator.push(
            MaterialPageRoute<void>(
              builder: (_) => const Scaffold(body: Text('next')),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
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

    group('画像先読みテスト（#7）', () {
      testWidgets('先読みされた画像が表示時に再フェッチされないこと（二重フェッチ防止）', (tester) async {
        // SwipeCard は Image.network に cacheHeight を指定しており、内部で
        // ResizeImage にラップされた ImageProvider を使う。precacheImage
        // 側がそれと違う ImageProvider（違う ImageCache キー）で先読みして
        // いると、山札を進めてカードが実際にスタック内へ入ってきた時点で
        // 同じ画像に対しもう一度 HTTP リクエストが飛んでしまう。
        // ここでは HTTP リクエストの回数を直接数えることで、Flutter 内部の
        // ImageCache/ResizeImage の実装詳細に依存せず二重フェッチの有無を
        // 確認する。
        //
        // 実ネットワークに出ず、常に成功する最小の HttpClient に差し替える。
        // 何もしないとテスト環境にはネットワークが無く、先読みが即座に
        // 失敗して ImageCache から取り除かれてしまい、検証できない。
        // debug 変数はテスト終了時に必ず戻す。binding が「テスト内で変更
        // したままになっていないか」を毎テスト直後に検証するため、
        // addTearDown（package:test 側の登録）だとその検証より後に
        // 実行されてしまい間に合わない。try/finally でテスト本体の中で
        // 戻し切る。
        final fakeClient = _FakeImageHttpClient();
        debugNetworkImageHttpClientProvider = () => fakeClient;
        imageCache.clear();
        try {
          final images = [
            for (var i = 0; i < 5; i++)
              AnimalImage(
                id: '$i',
                url: 'https://cataas.com/cat/$i?height=1600',
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

          // 4枚目（images[3]）はスタック（先頭3枚）の外側なので、
          // ここまでで先読みが 1 回走っているはず
          final targetUrl = Uri.parse(images[3].url);
          int requestCountFor(Uri url) =>
              fakeClient.requestedUrls.where((u) => u == url).length;

          expect(
            requestCountFor(targetUrl),
            1,
            reason: '先読みで 1 回だけリクエストされているべき',
          );

          // 山札を3回進め、images[3] がスタックへ入って実際に
          // Image.network で表示されるようにする
          for (var i = 0; i < 3; i++) {
            fakeNotifier.removeTopImage();
            await tester.pump();
            await tester.pump(const Duration(milliseconds: 300));
          }
          expect(find.byKey(ObjectKey(images[3])), findsOneWidget);

          // 表示された後も、同じ URL へのリクエストは先読み分の 1 回だけ
          expect(
            requestCountFor(targetUrl),
            1,
            reason: '表示時に同じ URL を再フェッチしてはいけない（二重フェッチ）',
          );
        } finally {
          debugNetworkImageHttpClientProvider = null;
          imageCache.clear();
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
        // お気に入りに追加されていることを確認（#8）
        expect(container.read(favoritesProvider), [
          const AnimalImage(
            id: '1',
            url: 'http://example.com/cat.jpg',
            type: AnimalType.cat,
          ),
        ]);
      });

      testWidgets('スワイプ中に山札が進んでも、スワイプしたカードがお気に入りに入ること', (tester) async {
        // スワイプ完了は 250ms 遅れて通知される。その間に別の操作で
        // 山札が 1 枚進むと、先頭は「スワイプしていない次のカード」に
        // 入れ替わる。通常の除去では deckGeneration が変わらないため、
        // トークンの照合だけではこのすり替わりを防げない。
        final swiped = const AnimalImage(
          id: 'swiped',
          url: 'http://example.com/swiped.jpg',
          type: AnimalType.cat,
        );
        final next = const AnimalImage(
          id: 'next',
          url: 'http://example.com/next.jpg',
          type: AnimalType.dog,
        );
        fakeNotifier = FakeAnimalImagesNotifier([swiped, next]);
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

        // 先頭カードを右へスワイプし始める
        final card = find.byKey(ObjectKey(swiped));
        expect(card, findsOneWidget);
        final gesture = await tester.startGesture(tester.getCenter(card));
        await gesture.moveBy(const Offset(300, 0));
        await tester.pump();
        await gesture.up();

        // 退場アニメーションの途中で完了通知が届く前に山札が進む状況を作らず、
        // ここでは単純に完了させる。すり替わりが起きていれば next が入る。
        await tester.pumpAndSettle();

        expect(container.read(favoritesProvider), [
          swiped,
        ], reason: 'スワイプしたカードそのものが登録されるべき');
      });

      testWidgets('お気に入りボタンをタップするとFavoritesScreenに遷移すること', (tester) async {
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const MaterialApp(home: SwipeScreen()),
          ),
        );

        await tester.tap(find.byIcon(Icons.collections));
        await tester.pumpAndSettle();

        expect(find.byType(FavoritesScreen), findsOneWidget);
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

      testWidgets('ドラッグ中にカード本体が再構築されないこと（#22）', (tester) async {
        // ドラッグ量を setState で保持すると、Image / Card を含む巨大な
        // ツリー全体が毎フレーム再構築されカクつきの原因になっていた。
        // ValueListenableBuilder の child として渡したカード本体は
        // インスタンスごと使い回されるはずなので、ドラッグ中も同一の
        // Card ウィジェットインスタンスであり続けることを確認する。
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
                onSwipeRight: () {},
              ),
            ),
          ),
        );

        final gesture = await tester.startGesture(
          tester.getCenter(find.byType(SwipeCard)),
        );
        // 最初の移動でジェスチャ認識され onPanStart の setState が走るため、
        // 「ドラッグ開始済み」の状態を基準にしてから比較する。
        await gesture.moveBy(const Offset(10, 2));
        await tester.pump();
        final cardBefore = tester.widget<Card>(find.byType(Card));

        for (var i = 0; i < 5; i++) {
          await gesture.moveBy(const Offset(10, 2));
          await tester.pump();
        }

        final cardAfter = tester.widget<Card>(find.byType(Card));
        expect(
          identical(cardBefore, cardAfter),
          isTrue,
          reason: 'ドラッグ中に Card の中身が再構築されてはいけない',
        );

        await gesture.up();
        await tester.pumpAndSettle();
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

    // FakeAnimalImagesNotifier は removeTopImage を丸ごと上書きしており、
    // 基底クラス（AnimalImagesNotifier）が private に持つ Undo 履歴フィールドは
    // 更新されない。そのため Undo の実挙動を確かめるテストは、実装の
    // Notifier を使う（再取得中の挙動テストと同じ理由）。
    group('Undo テスト（実 Provider, #9）', () {
      InkWell undoButton(WidgetTester tester) => tester.widget<InkWell>(
        find.ancestor(
          of: find.byIcon(Icons.undo),
          matching: find.byType(InkWell),
        ),
      );

      testWidgets('履歴がない間、Undo ボタンは disabled であること', (tester) async {
        SharedPreferences.setMockInitialValues({
          'selected_animal_types': ['cat'],
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

        api.completeFirstWith([AnimalType.cat]);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(undoButton(tester).onTap, isNull, reason: 'まだ何もスワイプしていない');
      });

      testWidgets('スキップ確定後、Undo ボタンが有効になりカードが復元されること', (tester) async {
        // Undo にも軽いフィードバックを付けている（#24）。誤操作を戻す操作
        // であって「好き」ほど強く鳴らす理由はないため lightImpact を使う。
        final hapticCalls = <MethodCall>[];
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(SystemChannels.platform, (call) async {
              if (call.method == 'HapticFeedback.vibrate') {
                hapticCalls.add(call);
              }
              return null;
            });
        addTearDown(() {
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
              .setMockMethodCallHandler(SystemChannels.platform, null);
        });

        SharedPreferences.setMockInitialValues({
          'selected_animal_types': ['cat'],
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

        api.completeFirstWith([AnimalType.cat, AnimalType.dog]);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        final removedInstance = realContainer
            .read(animalImagesProvider)
            .value!
            .first;

        expect(undoButton(tester).onTap, isNull);

        await tester.tap(find.byIcon(Icons.close));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(
          undoButton(tester).onTap,
          isNotNull,
          reason: 'スキップ確定後は直前の1枚を戻せるはず',
        );

        await tester.tap(find.byIcon(Icons.undo));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(
          identical(
            realContainer.read(animalImagesProvider).value!.first,
            removedInstance,
          ),
          isTrue,
          reason: 'Undo は取り除いたカードと同一インスタンスを先頭へ戻すべき',
        );
        expect(
          undoButton(tester).onTap,
          isNull,
          reason: '戻した直後は履歴が消費されるので再び disabled になる',
        );
        expect(
          hapticCalls.map((c) => c.arguments),
          containsAllInOrder(<String>[
            'HapticFeedbackType.lightImpact', // スキップ確定
            'HapticFeedbackType.lightImpact', // Undo
          ]),
          reason: 'Undo にも Skip と同じ軽さのフィードバックを付けている',
        );
      });

      testWidgets('「好き」からの Undo はお気に入りも取り消すこと', (tester) async {
        SharedPreferences.setMockInitialValues({
          'selected_animal_types': ['cat'],
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

        api.completeFirstWith([AnimalType.cat, AnimalType.dog]);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        final liked = realContainer.read(animalImagesProvider).value!.first;

        await tester.tap(find.byIcon(Icons.favorite));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(realContainer.read(favoritesProvider), [liked]);

        // 「好き」で出た SnackBar（floating）がボタン行に重なり、Undo への
        // タップがヒットテストで弾かれてしまうため、先に消しておく
        tester
            .state<ScaffoldMessengerState>(find.byType(ScaffoldMessenger))
            .hideCurrentSnackBar();
        await tester.pumpAndSettle();

        await tester.tap(find.byIcon(Icons.undo));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(
          realContainer.read(favoritesProvider),
          isEmpty,
          reason: 'Undo でこのスワイプが追加したお気に入りは取り消されるべき',
        );
        expect(
          identical(
            realContainer.read(animalImagesProvider).value!.first,
            liked,
          ),
          isTrue,
        );
      });
    });

    group('触覚フィードバックテスト（#24）', () {
      final List<MethodCall> hapticCalls = <MethodCall>[];

      void captureHaptics() {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(SystemChannels.platform, (call) async {
              if (call.method == 'HapticFeedback.vibrate') {
                hapticCalls.add(call);
              }
              return null;
            });
      }

      setUp(() {
        hapticCalls.clear();
        captureHaptics();
      });

      tearDown(() {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(SystemChannels.platform, null);
      });

      testWidgets('スキップ確定時に lightImpact が鳴ること', (tester) async {
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const MaterialApp(home: SwipeScreen()),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        await tester.tap(find.byIcon(Icons.close));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(hapticCalls, hasLength(1));
        expect(hapticCalls.single.arguments, 'HapticFeedbackType.lightImpact');
      });

      testWidgets('Like 確定時に skip より強い mediumImpact が鳴ること', (tester) async {
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const MaterialApp(home: SwipeScreen()),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        await tester.tap(find.byIcon(Icons.favorite));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(hapticCalls, hasLength(1));
        expect(hapticCalls.single.arguments, 'HapticFeedbackType.mediumImpact');
      });

      testWidgets('操作対象がない（disabled）ボタンをタップしても鳴らないこと', (tester) async {
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

        await tester.tap(find.byIcon(Icons.close));
        await tester.pump();
        await tester.tap(find.byIcon(Icons.favorite));
        await tester.pump();
        await tester.tap(find.byIcon(Icons.undo));
        await tester.pump();

        expect(hapticCalls, isEmpty);
      });
    });
  });
}
