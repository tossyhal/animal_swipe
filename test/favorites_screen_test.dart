// test/favorites_screen_test.dart
import 'package:animal_swipe/constants/app_strings.dart';
import 'package:animal_swipe/models/animal_model.dart';
import 'package:animal_swipe/models/animal_type.dart';
import 'package:animal_swipe/providers/favorites_provider.dart';
import 'package:animal_swipe/screens/favorites_screen.dart';
import 'package:animal_swipe/services/prefs_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('FavoritesScreen ウィジェットテスト', () {
    late ProviderContainer container;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      container = ProviderContainer(
        overrides: [
          prefsServiceProvider.overrideWithValue(PrefsService(prefs)),
        ],
      );
    });

    tearDown(() {
      container.dispose();
    });

    testWidgets('お気に入りが空の場合は空状態のメッセージが表示されること', (tester) async {
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: FavoritesScreen()),
        ),
      );

      expect(find.text(AppStrings.favoritesEmptyTitle), findsOneWidget);
      expect(find.byType(GridView), findsNothing);
    });

    testWidgets('お気に入りがある場合はグリッドに表示されること', (tester) async {
      container
          .read(favoritesProvider.notifier)
          .add(
            const AnimalImage(
              id: '1',
              url: 'https://example.com/1.jpg',
              type: AnimalType.cat,
            ),
          );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: FavoritesScreen()),
        ),
      );

      expect(find.byType(GridView), findsOneWidget);
      expect(find.text(AppStrings.favoritesEmptyTitle), findsNothing);
    });

    testWidgets('長押しして削除を確定するとお気に入りから消えること', (tester) async {
      container
          .read(favoritesProvider.notifier)
          .add(
            const AnimalImage(
              id: '1',
              url: 'https://example.com/1.jpg',
              type: AnimalType.cat,
            ),
          );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: FavoritesScreen()),
        ),
      );

      await tester.longPress(find.byType(InkWell).first);
      await tester.pumpAndSettle();

      expect(find.text(AppStrings.favoritesDeleteDialogTitle), findsOneWidget);

      await tester.tap(find.text(AppStrings.favoritesDeleteDialogConfirm));
      await tester.pumpAndSettle();

      expect(container.read(favoritesProvider), isEmpty);
      expect(find.text(AppStrings.favoritesEmptyTitle), findsOneWidget);
    });

    testWidgets('長押しして削除をキャンセルするとお気に入りは残ること', (tester) async {
      container
          .read(favoritesProvider.notifier)
          .add(
            const AnimalImage(
              id: '1',
              url: 'https://example.com/1.jpg',
              type: AnimalType.cat,
            ),
          );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: FavoritesScreen()),
        ),
      );

      await tester.longPress(find.byType(InkWell).first);
      await tester.pumpAndSettle();

      await tester.tap(find.text(AppStrings.favoritesDialogCancel));
      await tester.pumpAndSettle();

      expect(container.read(favoritesProvider).length, 1);
    });

    testWidgets('グリッドのサムネイルが原寸でデコードされないこと', (tester) async {
      container
          .read(favoritesProvider.notifier)
          .add(
            const AnimalImage(
              id: '1',
              url: 'https://example.com/1.jpg',
              type: AnimalType.cat,
            ),
          );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: FavoritesScreen()),
        ),
      );

      // タイルは画面幅の 1/3 しか占めないので、原寸デコード（cacheWidth
      // 未指定）だと 200 件スクロールで ImageCache を食い潰す
      final image = tester.widget<Image>(
        find.descendant(
          of: find.byType(GridView),
          matching: find.byType(Image),
        ),
      );
      final provider = image.image;
      expect(
        provider,
        isA<ResizeImage>(),
        reason: 'cacheWidth が指定されていれば ResizeImage でラップされる',
      );
    });

    testWidgets('サムネイルの解像度が近い画面幅でバケツを共有すること', (tester) async {
      // 1px 変わるたびにキーがずれると、リサイズのたびに全タイルが
      // 再デコードされる
      Future<int?> resolve(double screenWidth) async {
        int? captured;
        await tester.pumpWidget(
          MediaQuery(
            data: MediaQueryData(
              size: Size(screenWidth, 800),
              devicePixelRatio: 2,
            ),
            child: Builder(
              builder: (context) {
                captured = favoritesThumbnailCacheWidth(context);
                return const SizedBox.shrink();
              },
            ),
          ),
        );
        return captured;
      }

      final narrow = await resolve(390);
      expect(narrow, isNotNull);
      expect(narrow, await resolve(400));
    });
  });
}
