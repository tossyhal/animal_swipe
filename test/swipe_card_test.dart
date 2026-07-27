// test/swipe_card_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:animal_swipe/widgets/swipe_card.dart';
import 'package:animal_swipe/models/animal_model.dart';
import 'package:animal_swipe/models/animal_type.dart';

void main() {
  late AnimalImage testImage;

  setUp(() {
    testImage = const AnimalImage(
      id: '1',
      url: 'http://example.com/cat.jpg',
      type: AnimalType.cat,
      description: 'Test Cat',
      source: 'The Cat API',
    );
  });

  group('SwipeCard UIコンポーネントテスト', () {
    testWidgets('カードが正しく表示されること', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SwipeCard(
              image: testImage,
              onSwipeLeft: () {},
              onSwipeRight: () {},
            ),
          ),
        ),
      );

      // カードが表示されていることを確認
      expect(find.byType(Card), findsOneWidget);
      expect(find.byType(Image), findsOneWidget);

      // 画像のURLが正しく設定されていることを確認
      //
      // cacheHeight（#7）を指定しているため、実際の ImageProvider は
      // Image.network が内部で ResizeImage にラップしたものになる。
      final Image image = tester.widget<Image>(find.byType(Image));
      final resized = image.image as ResizeImage;
      expect(
        (resized.imageProvider as NetworkImage).url,
        testImage.url,
        reason: '画像のURLが正しく設定されていること',
      );
    });

    testWidgets('cacheHeight が画面高さと devicePixelRatio から計算されること（#7）', (
      tester,
    ) async {
      // メモリ使用量削減のため、原寸のままデコードせずカードの表示高さ相当に
      // 縮小させる。cacheHeight は ResizeImage 経由で Image.image に反映される。
      // 表示は BoxFit.cover のポートレートペインなので、拡大率を決めるのは
      // 幅ではなく高さ側（cardImageCacheHeight のコメント参照）。
      //
      // cardImageCacheHeight はカードの実測レイアウト高さではなく画面高さを
      // 基準にしている（SwipeScreen 側の先読みと同じ値を再現するため）。
      // そのためここでは MediaQuery.size を明示的に指定して検証する。
      //
      // 300 論理px × DPR 2 = 600 device px を 256 単位で切り上げると 768。
      // kCatImageHeight（1600）未満なのでクランプされず、バケツ丸めの
      // 結果だけを検証できる値を選んでいる。
      const mediaQueryData = MediaQueryData(
        size: Size(400, 300),
        devicePixelRatio: 2,
      );
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: mediaQueryData,
            child: Scaffold(
              body: SwipeCard(
                image: testImage,
                onSwipeLeft: () {},
                onSwipeRight: () {},
              ),
            ),
          ),
        ),
      );

      final Image image = tester.widget<Image>(find.byType(Image));
      final resized = image.image as ResizeImage;

      expect(resized.height, isNotNull);
      expect(
        resized.height,
        768,
        reason: '600 device px を 256 単位バケツに切り上げた値になるべき',
      );
    });

    testWidgets('近いビューポート高さは同じ cacheHeight バケツを共有すること（#7 リクエストの嵐対策）', (
      tester,
    ) async {
      // ウィンドウリサイズ・分割画面・回転のたびに 1px 単位で ImageCache の
      // キーが変わると、表示中のカードが総入れ替えで再フェッチされる
      // 「リクエストの嵐」が起きる。256px バケツに丸めることで、近い
      // 高さのビューポートは同じキー（＝同じ cacheHeight）を共有し、
      // リサイズのたびにキーがずれるのを防ぐ。
      //
      // 590px と 600px はどちらも 256 単位バケツで 768 に丸まる
      // （ceil(590/256) == ceil(600/256) == 3）。
      Future<int?> cacheHeightFor(double height) async {
        await tester.pumpWidget(
          MaterialApp(
            home: MediaQuery(
              data: MediaQueryData(
                size: Size(400, height),
                devicePixelRatio: 1,
              ),
              child: Scaffold(
                body: SwipeCard(
                  image: testImage,
                  onSwipeLeft: () {},
                  onSwipeRight: () {},
                ),
              ),
            ),
          ),
        );
        final Image image = tester.widget<Image>(find.byType(Image));
        return (image.image as ResizeImage).height;
      }

      final first = await cacheHeightFor(590);
      final second = await cacheHeightFor(600);

      expect(first, isNotNull);
      expect(second, first, reason: '590px と 600px は同じ 256 単位バケツ（768）に収まるべき');
    });

    testWidgets('動物の種類と説明が表示されること', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SwipeCard(
              image: testImage,
              onSwipeLeft: () {},
              onSwipeRight: () {},
            ),
          ),
        ),
      );

      expect(find.text('CAT'), findsOneWidget);
      expect(find.text('Test Cat'), findsOneWidget);
    });
  });

  group('SwipeCard インタラクションテスト', () {
    testWidgets('右スワイプでコールバックが呼ばれること', (tester) async {
      bool swipedRight = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SwipeCard(
              image: testImage,
              onSwipeLeft: () {},
              onSwipeRight: () {
                swipedRight = true;
              },
            ),
          ),
        ),
      );

      // 右方向へのドラッグ
      await tester.drag(find.byType(Card), const Offset(400, 0));
      await tester.pumpAndSettle();

      expect(swipedRight, isTrue, reason: '右スワイプのコールバックが呼ばれること');
    });

    testWidgets('左スワイプでコールバックが呼ばれること', (tester) async {
      bool swipedLeft = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SwipeCard(
              image: testImage,
              onSwipeLeft: () {
                swipedLeft = true;
              },
              onSwipeRight: () {},
            ),
          ),
        ),
      );

      // 左方向へのドラッグ
      await tester.drag(find.byType(Card), const Offset(-400, 0));
      await tester.pumpAndSettle();

      expect(swipedLeft, isTrue, reason: '左スワイプのコールバックが呼ばれること');
    });

    testWidgets('スワイプ閾値以下の移動ではコールバックが呼ばれないこと', (tester) async {
      bool swipedLeft = false;
      bool swipedRight = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SwipeCard(
              image: testImage,
              onSwipeLeft: () {
                swipedLeft = true;
              },
              onSwipeRight: () {
                swipedRight = true;
              },
            ),
          ),
        ),
      );

      // 小さな移動距離でのドラッグ
      await tester.drag(find.byType(Card), const Offset(50, 0));
      await tester.pumpAndSettle();

      expect(swipedRight, isFalse, reason: '小さな右移動ではコールバックが呼ばれないこと');
      expect(swipedLeft, isFalse, reason: '小さな左移動ではコールバックが呼ばれないこと');
    });

    testWidgets('垂直方向のスワイプではコールバックが呼ばれないこと', (tester) async {
      bool swipedLeft = false;
      bool swipedRight = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SwipeCard(
              image: testImage,
              onSwipeLeft: () {
                swipedLeft = true;
              },
              onSwipeRight: () {
                swipedRight = true;
              },
            ),
          ),
        ),
      );

      // 垂直方向へのドラッグ
      await tester.drag(find.byType(Card), const Offset(0, 300));
      await tester.pumpAndSettle();

      expect(swipedRight, isFalse, reason: '垂直方向のスワイプではコールバックが呼ばれないこと');
      expect(swipedLeft, isFalse, reason: '垂直方向のスワイプではコールバックが呼ばれないこと');
    });
  });
}
