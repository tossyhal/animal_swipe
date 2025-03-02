// test/swipe_card_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:animal_swipe/widgets/swipe_card.dart';
import 'package:animal_swipe/models/animal_model.dart';

void main() {
  late AnimalImage testImage;

  setUp(() {
    testImage = AnimalImage(
      id: '1',
      url: 'http://example.com/cat.jpg',
      type: 'cat',
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
      final Image image = tester.widget<Image>(find.byType(Image));
      expect(
        (image.image as NetworkImage).url,
        testImage.url,
        reason: '画像のURLが正しく設定されていること',
      );
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
