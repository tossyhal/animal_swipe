// test/animal_providers_test.dart
import 'package:animal_swipe/models/animal_model.dart';
import 'package:animal_swipe/models/animal_type.dart';
import 'package:animal_swipe/providers/animal_providers.dart';
import 'package:animal_swipe/providers/favorites_provider.dart';
import 'package:animal_swipe/services/api_service.dart';
import 'package:animal_swipe/services/prefs_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// テスト用の固定画像リストを返すだけの [IApiService]
class _FixedApiService implements IApiService {
  List<AnimalImage> images;

  _FixedApiService(this.images);

  @override
  Future<List<AnimalImage>> fetchImages(List<AnimalType> types) async {
    return images;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SelectedAnimalTypesNotifier テスト', () {
    late ProviderContainer container;
    late PrefsService prefsService;
    late SharedPreferences prefs;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
      prefsService = PrefsService(prefs);
      container = ProviderContainer(
        overrides: [prefsServiceProvider.overrideWithValue(prefsService)],
      );
    });

    tearDown(() {
      container.dispose();
    });

    group('基本機能のテスト', () {
      test('初期状態は空のリストであること', () {
        final selectedTypes = container.read(selectedAnimalTypesProvider);
        expect(selectedTypes, isEmpty);
      });

      test('動物タイプを追加すると、リストに追加されること', () {
        final notifier = container.read(selectedAnimalTypesProvider.notifier);
        notifier.selectType(AnimalType.cat, true);
        expect(container.read(selectedAnimalTypesProvider), [
          AnimalType.cat,
        ], reason: '猫が正しく追加されていること');
      });

      test('動物タイプを削除すると、リストから削除されること', () {
        final notifier = container.read(selectedAnimalTypesProvider.notifier);
        // 準備：まず動物を追加
        notifier.selectType(AnimalType.dog, true);
        notifier.selectType(AnimalType.cat, true);

        // 実行：猫を削除
        notifier.selectType(AnimalType.cat, false);

        // 検証
        expect(
          container.read(selectedAnimalTypesProvider),
          [AnimalType.dog],
          reason: '猫が正しく削除され、犬のみが残っていること',
        );
      });
    });

    group('エッジケースのテスト', () {
      test('同じ動物タイプを複数回追加しても、1回だけ追加されること', () {
        final notifier = container.read(selectedAnimalTypesProvider.notifier);
        notifier.selectType(AnimalType.cat, true);
        notifier.selectType(AnimalType.cat, true);
        notifier.selectType(AnimalType.cat, true);

        expect(container.read(selectedAnimalTypesProvider), [
          AnimalType.cat,
        ], reason: '重複した追加を防止できていること');
      });

      test('選択されていない動物タイプを削除しても、エラーが発生しないこと', () {
        final notifier = container.read(selectedAnimalTypesProvider.notifier);
        // 実行時にエラーが発生しないことを確認
        expect(
          () => notifier.selectType(AnimalType.dog, false),
          returnsNormally,
        );
      });

      // #15 以前は空文字列や 'nonexistent' を弾くランタイム検証が必要だったが、
      // AnimalType になったことで「存在しない動物タイプ」はそもそも渡せない。
      // 検証はランタイムから型システムへ移った。
      test('選択肢は AnimalType.values に限られる', () {
        final notifier = container.read(selectedAnimalTypesProvider.notifier);
        for (final type in AnimalType.values) {
          notifier.selectType(type, true);
        }

        expect(
          container.read(selectedAnimalTypesProvider),
          AnimalType.values,
          reason: '全ての動物タイプを選択できること',
        );
      });
    });

    group('永続化のテスト', () {
      test('選択した動物タイプがSharedPreferencesに保存されること', () async {
        final notifier = container.read(selectedAnimalTypesProvider.notifier);
        notifier.selectType(AnimalType.cat, true);
        notifier.selectType(AnimalType.dog, true);

        // SharedPreferences には AnimalType.id の文字列で保存される
        final savedTypes = prefs.getStringList('selected_animal_types');
        expect(savedTypes, ['cat', 'dog'], reason: '選択した動物タイプが正しく保存されていること');
      });

      test('アプリ再起動時に保存された動物タイプが復元されること', () async {
        // 初期データを保存
        await prefs.setStringList('selected_animal_types', ['cat', 'dog']);

        // 新しいコンテナを作成（アプリ再起動をシミュレート）
        final newContainer = ProviderContainer(
          overrides: [
            prefsServiceProvider.overrideWithValue(PrefsService(prefs)),
          ],
        );
        addTearDown(newContainer.dispose);

        // 保存されていたデータが復元されていることを確認
        expect(
          newContainer.read(selectedAnimalTypesProvider),
          [AnimalType.cat, AnimalType.dog],
          reason: '保存されていた動物タイプが正しく復元されること',
        );
      });

      // 端末に残った古い選択（あるいは将来追加予定の動物）で
      // 起動に失敗させないこと。
      test('保存済みデータに未知の動物 id が混ざっていても無視される', () async {
        await prefs.setStringList('selected_animal_types', [
          'cat',
          'bird',
          'dog',
          '',
        ]);

        final newContainer = ProviderContainer(
          overrides: [
            prefsServiceProvider.overrideWithValue(PrefsService(prefs)),
          ],
        );
        addTearDown(newContainer.dispose);

        expect(
          newContainer.read(selectedAnimalTypesProvider),
          [AnimalType.cat, AnimalType.dog],
          reason: '未知の id は落とし、既知のものだけを復元すること',
        );
      });
    });
  });

  group('AnimalImagesNotifier の Undo テスト（#9）', () {
    late ProviderContainer container;
    late _FixedApiService apiService;

    setUp(() async {
      SharedPreferences.setMockInitialValues({
        'selected_animal_types': ['cat'],
      });
      final prefs = PrefsService(await SharedPreferences.getInstance());
      apiService = _FixedApiService([
        const AnimalImage(
          id: 'a',
          url: 'http://example.com/a.jpg',
          type: AnimalType.cat,
        ),
        const AnimalImage(
          id: 'b',
          url: 'http://example.com/b.jpg',
          type: AnimalType.cat,
        ),
        const AnimalImage(
          id: 'c',
          url: 'http://example.com/c.jpg',
          type: AnimalType.cat,
        ),
      ]);
      container = ProviderContainer(
        overrides: [
          prefsServiceProvider.overrideWithValue(prefs),
          apiServiceProvider.overrideWithValue(apiService),
        ],
      );
      addTearDown(container.dispose);
      // build() が終わるまで待つ
      await container.read(animalImagesProvider.future);
    });

    test('スワイプ直後は canUndo が true になり、履歴がなければ false', () {
      final notifier = container.read(animalImagesProvider.notifier);
      expect(notifier.canUndo, isFalse, reason: 'まだ何もスワイプしていない');

      final deckToken = notifier.deckGeneration;
      final top = container.read(animalImagesProvider).value!.first;
      notifier.removeTopImage(deckToken: deckToken, expectedTop: top);

      expect(notifier.canUndo, isTrue, reason: '直前の1枚は戻せる状態のはず');
    });

    test('Undo は取り除いたカードと同一インスタンスを先頭へ戻す', () {
      final notifier = container.read(animalImagesProvider.notifier);
      final deckToken = notifier.deckGeneration;
      final removedInstance = container.read(animalImagesProvider).value!.first;

      notifier.removeTopImage(
        deckToken: deckToken,
        expectedTop: removedInstance,
      );
      expect(
        container.read(animalImagesProvider).value!.first.id,
        'b',
        reason: '1枚除去した後は次のカードが先頭になっている',
      );

      final result = notifier.undo();
      expect(result, isNotNull);
      expect(result!.image, same(removedInstance));

      final restoredTop = container.read(animalImagesProvider).value!.first;
      expect(
        identical(restoredTop, removedInstance),
        isTrue,
        reason:
            'ObjectKey は identical 比較なので、コピーではなく同一インスタンスを'
            '戻さないと _CardStack 側で別カード扱いになってしまう',
      );
    });

    test('Undo は履歴がなければ何もせず null を返す（ボタンは disabled 相当）', () {
      final notifier = container.read(animalImagesProvider.notifier);
      expect(notifier.canUndo, isFalse);

      final before = container.read(animalImagesProvider).value;
      final result = notifier.undo();

      expect(result, isNull);
      expect(
        container.read(animalImagesProvider).value,
        same(before),
        reason: '履歴がない Undo は state を一切変更してはいけない',
      );
    });

    test('古い山札のカードは reload 後に Undo で復元できない', () async {
      final notifier = container.read(animalImagesProvider.notifier);
      final deckToken = notifier.deckGeneration;
      final removedInstance = container.read(animalImagesProvider).value!.first;

      notifier.removeTopImage(
        deckToken: deckToken,
        expectedTop: removedInstance,
      );
      expect(notifier.canUndo, isTrue, reason: 'reload 前はまだ戻せる');

      // 山札を取り直す（reload）→ 新しい世代の山札に入れ替わる
      apiService.images = [
        const AnimalImage(
          id: 'z',
          url: 'http://example.com/z.jpg',
          type: AnimalType.cat,
        ),
      ];
      await notifier.reload();

      expect(notifier.canUndo, isFalse, reason: '山札が入れ替わった後、古い山札のカードは戻せない');
      expect(notifier.undo(), isNull);

      final currentImages = container.read(animalImagesProvider).value!;
      expect(
        currentImages.any((image) => identical(image, removedInstance)),
        isFalse,
        reason: '古い山札のカードが新しい山札に紛れ込んではいけない',
      );
    });
  });

  group('AnimalImagesNotifier の Undo とお気に入りの連動テスト（#9）', () {
    late ProviderContainer container;

    setUp(() async {
      SharedPreferences.setMockInitialValues({
        'selected_animal_types': ['cat'],
      });
      final prefs = PrefsService(await SharedPreferences.getInstance());
      final apiService = _FixedApiService([
        const AnimalImage(
          id: 'a',
          url: 'http://example.com/a.jpg',
          type: AnimalType.cat,
        ),
        const AnimalImage(
          id: 'b',
          url: 'http://example.com/b.jpg',
          type: AnimalType.cat,
        ),
      ]);
      container = ProviderContainer(
        overrides: [
          prefsServiceProvider.overrideWithValue(prefs),
          apiServiceProvider.overrideWithValue(apiService),
        ],
      );
      addTearDown(container.dispose);
      await container.read(animalImagesProvider.future);
    });

    test('右スワイプ相当（undoRemovesFavorite: true）の Undo はお気に入りも取り消す', () {
      final notifier = container.read(animalImagesProvider.notifier);
      final favoritesNotifier = container.read(favoritesProvider.notifier);
      final deckToken = notifier.deckGeneration;
      final swiped = container.read(animalImagesProvider).value!.first;

      // SwipeScreen._like と同じ手順：先に isFavorite を見てから
      // removeTopImage → add する
      final alreadyFavorite = favoritesNotifier.isFavorite(swiped);
      notifier.removeTopImage(
        deckToken: deckToken,
        expectedTop: swiped,
        undoRemovesFavorite: !alreadyFavorite,
      );
      favoritesNotifier.add(swiped);
      expect(favoritesNotifier.isFavorite(swiped), isTrue);

      final result = notifier.undo();
      expect(result, isNotNull);
      expect(result!.shouldUnfavorite, isTrue);
      if (result.shouldUnfavorite) favoritesNotifier.remove(result.image);

      expect(
        favoritesNotifier.isFavorite(swiped),
        isFalse,
        reason: 'Undo でこのスワイプが追加したお気に入りは取り消されるべき',
      );
    });

    test('既にお気に入り済みの画像を再度「好き」しても、Undo で既存のお気に入りは消えない', () {
      final notifier = container.read(animalImagesProvider.notifier);
      final favoritesNotifier = container.read(favoritesProvider.notifier);
      final swiped = container.read(animalImagesProvider).value!.first;

      // 別ルートで既にお気に入り登録済みという状況を再現
      favoritesNotifier.add(swiped);
      expect(favoritesNotifier.isFavorite(swiped), isTrue);

      final deckToken = notifier.deckGeneration;
      final alreadyFavorite = favoritesNotifier.isFavorite(swiped);
      notifier.removeTopImage(
        deckToken: deckToken,
        expectedTop: swiped,
        undoRemovesFavorite: !alreadyFavorite,
      );
      // 既に登録済みなので add は何もしない
      favoritesNotifier.add(swiped);

      final result = notifier.undo();
      expect(result, isNotNull);
      expect(
        result!.shouldUnfavorite,
        isFalse,
        reason: 'このスワイプがお気に入りを新規追加したわけではない',
      );
      if (result.shouldUnfavorite) favoritesNotifier.remove(result.image);

      expect(
        favoritesNotifier.isFavorite(swiped),
        isTrue,
        reason: 'このスワイプより前からのお気に入りを誤って消してはいけない',
      );
    });

    test('左スワイプ（skip）の Undo はお気に入りに影響しない', () {
      final notifier = container.read(animalImagesProvider.notifier);
      final favoritesNotifier = container.read(favoritesProvider.notifier);
      final deckToken = notifier.deckGeneration;
      final swiped = container.read(animalImagesProvider).value!.first;

      notifier.removeTopImage(deckToken: deckToken, expectedTop: swiped);

      final result = notifier.undo();
      expect(result, isNotNull);
      expect(result!.shouldUnfavorite, isFalse);
      expect(favoritesNotifier.isFavorite(swiped), isFalse);
    });
  });
}
