// test/favorites_provider_test.dart
import 'package:animal_swipe/models/animal_model.dart';
import 'package:animal_swipe/models/animal_type.dart';
import 'package:animal_swipe/providers/favorites_provider.dart';
import 'package:animal_swipe/services/prefs_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

AnimalImage _image(String id, {AnimalType type = AnimalType.cat}) =>
    AnimalImage(id: id, url: 'https://example.com/$id.jpg', type: type);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('FavoritesNotifier テスト', () {
    late ProviderContainer container;
    late PrefsService prefsService;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      prefsService = PrefsService(prefs);
      container = ProviderContainer(
        overrides: [prefsServiceProvider.overrideWithValue(prefsService)],
      );
    });

    tearDown(() {
      container.dispose();
    });

    test('初期状態は空のリストであること', () {
      expect(container.read(favoritesProvider), isEmpty);
    });

    test('追加すると一覧に反映され、永続化されること', () {
      final notifier = container.read(favoritesProvider.notifier);
      final image = _image('1');

      notifier.add(image);

      expect(container.read(favoritesProvider), [image]);
      expect(prefsService.getFavorites(), [image]);
    });

    test('同じ画像を2回追加しても1件のままであること', () {
      final notifier = container.read(favoritesProvider.notifier);
      final image = _image('1');

      notifier.add(image);
      notifier.add(image);

      expect(container.read(favoritesProvider), [image]);
    });

    test('削除すると一覧から消え、永続化されること', () {
      final notifier = container.read(favoritesProvider.notifier);
      final image = _image('1');

      notifier.add(image);
      notifier.remove(image);

      expect(container.read(favoritesProvider), isEmpty);
      expect(prefsService.getFavorites(), isEmpty);
    });

    test('追加されていない画像を削除しても何も起きないこと', () {
      final notifier = container.read(favoritesProvider.notifier);

      expect(() => notifier.remove(_image('missing')), returnsNormally);
      expect(container.read(favoritesProvider), isEmpty);
    });

    test('toggle は未登録なら追加、登録済みなら削除すること', () {
      final notifier = container.read(favoritesProvider.notifier);
      final image = _image('1');

      notifier.toggle(image);
      expect(notifier.isFavorite(image), isTrue);

      notifier.toggle(image);
      expect(notifier.isFavorite(image), isFalse);
    });

    test('上限を超えたら最も古いお気に入りが追い出されること', () {
      final notifier = container.read(favoritesProvider.notifier);

      for (var i = 0; i < FavoritesNotifier.maxFavorites; i++) {
        notifier.add(_image('img-$i'));
      }
      expect(
        container.read(favoritesProvider).length,
        FavoritesNotifier.maxFavorites,
      );

      // 上限ちょうどの状態でもう1件追加する
      notifier.add(_image('overflow'));

      final favorites = container.read(favoritesProvider);
      expect(favorites.length, FavoritesNotifier.maxFavorites);
      // 一番古い img-0 が追い出され、新しい overflow が末尾に残る
      expect(favorites.any((f) => f.id == 'img-0'), isFalse);
      expect(favorites.last.id, 'overflow');
    });

    test('アプリ再起動時に保存されたお気に入りが復元されること', () async {
      final notifier = container.read(favoritesProvider.notifier);
      notifier.add(_image('1'));

      final newContainer = ProviderContainer(
        overrides: [prefsServiceProvider.overrideWithValue(prefsService)],
      );
      addTearDown(newContainer.dispose);

      expect(newContainer.read(favoritesProvider), [_image('1')]);
    });
  });
}
