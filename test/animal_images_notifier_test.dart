// test/animal_images_notifier_test.dart
import 'dart:async';

import 'package:animal_swipe/models/animal_model.dart';
import 'package:animal_swipe/providers/animal_providers.dart';
import 'package:animal_swipe/services/api_service.dart'
    show IApiService, apiServiceProvider;
import 'package:animal_swipe/services/prefs_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// テスト用データを返すダミーの ApiService
class FakeApiService implements IApiService {
  @override
  Future<List<AnimalImage>> fetchImages(List<String> types) async {
    // 各動物タイプごとに1件のダミーデータを返す
    return types
        .map(
          (type) => AnimalImage(
            id: type,
            url: 'http://example.com/$type.jpg',
            type: type,
          ),
        )
        .toList();
  }
}

/// 常に空リストを返す ApiService
class EmptyApiService implements IApiService {
  @override
  Future<List<AnimalImage>> fetchImages(List<String> types) async => [];
}

/// 応答を任意のタイミングまで保留できる ApiService。
/// 「リクエスト中に選択が変わる」競合状態を決定的に再現するために使う。
class DeferredApiService implements IApiService {
  final _pending = <Completer<List<AnimalImage>>>[];

  @override
  Future<List<AnimalImage>> fetchImages(List<String> types) {
    final completer = Completer<List<AnimalImage>>();
    _pending.add(completer);
    return completer.future;
  }

  /// 保留中の最初のリクエストに、指定タイプの画像を1件ずつ返す
  void completeFirstWith(List<String> types) {
    _pending.removeAt(0).complete(
      types
          .map(
            (type) => AnimalImage(
              id: type,
              url: 'http://example.com/$type.jpg',
              type: type,
            ),
          )
          .toList(),
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AnimalImagesNotifier テスト', () {
    late PrefsService prefsService;

    /// 選択済みタイプと ApiService を差し替えた [ProviderContainer] を作る
    ProviderContainer createContainer(IApiService apiService) {
      final container = ProviderContainer(
        overrides: [
          prefsServiceProvider.overrideWithValue(prefsService),
          apiServiceProvider.overrideWithValue(apiService),
        ],
      );
      addTearDown(container.dispose);
      return container;
    }

    setUp(() async {
      SharedPreferences.setMockInitialValues({
        'selected_animal_types': ['cat', 'dog'],
      });
      prefsService = PrefsService(await SharedPreferences.getInstance());
    });

    // 初期画像ロード処理が正しく動作するかを検証
    test('初期画像のロード', () async {
      final container = createContainer(FakeApiService());

      await container.read(animalImagesProvider.notifier).loadInitialImages();

      // 選択した動物タイプごとに1件ずつ返るため、件数は2件であるはず
      expect(container.read(animalImagesProvider).length, 2);
    });

    // トップ画像削除後、必要に応じて追加読み込みが実行されることを検証
    test('トップ画像の削除後、追加読み込みが実行される', () async {
      final container = createContainer(FakeApiService());
      final notifier = container.read(animalImagesProvider.notifier);

      await notifier.loadInitialImages();
      final initialLength = container.read(animalImagesProvider).length;
      notifier.removeTopImage();
      final afterRemovalLength = container.read(animalImagesProvider).length;

      // トップ画像が削除され、残り件数が閾値以下なら追加読み込みが行われるため、
      // 件数が初期より減少しているが、場合によっては追加で増えている可能性がある
      expect(afterRemovalLength >= initialLength - 1, true);
    });

    // Notifier のフィールドを late final にすると、依存の変化で build() が
    // 再実行された際に LateInitializationError になる。その回帰を防ぐ。
    test('選択タイプが変わっても build() の再実行で例外にならない', () async {
      final container = createContainer(FakeApiService());

      await container.read(animalImagesProvider.notifier).loadInitialImages();
      expect(container.read(animalImagesProvider).length, 2);

      // 選択を変更して animalImagesProvider の再 build を発生させる
      container
          .read(selectedAnimalTypesProvider.notifier)
          .selectType('dog', false);

      expect(() => container.read(animalImagesProvider), returnsNormally);
      await container.read(animalImagesProvider.notifier).loadInitialImages();
      expect(container.read(animalImagesProvider).length, 1);
    });

    // 選択変更前に投げたリクエストの応答が、変更後の state を汚染しないこと。
    test('選択変更前に開始したリクエストの結果は破棄される', () async {
      final api = DeferredApiService();
      final container = createContainer(api);

      // cat + dog で読み込みを開始（まだ応答は返さない）
      final loading = container
          .read(animalImagesProvider.notifier)
          .loadInitialImages();

      // 応答が返る前に dog を外す → animalImagesProvider が再 build される
      container
          .read(selectedAnimalTypesProvider.notifier)
          .selectType('dog', false);

      // 古い選択（cat + dog）に対する応答をいま返す
      api.completeFirstWith(['cat', 'dog']);
      await loading;

      // 古い応答は捨てられ、外したはずの dog が混ざらないこと
      expect(container.read(animalImagesProvider), isEmpty);
      // 新しい選択で読み込み直せること（_isLoading が倒れている）
      final reload = container
          .read(animalImagesProvider.notifier)
          .loadInitialImages();
      api.completeFirstWith(['cat']);
      await reload;

      final images = container.read(animalImagesProvider);
      expect(images.map((i) => i.type), ['cat']);
    });

    // 古いリクエストが後から完了しても、後発リクエストの読み込み中表示を
    // 巻き戻さないこと。巻き戻すと二重読み込みを許してしまう。
    test('古いリクエストの完了が後発リクエストのローディングを解除しない', () async {
      final api = DeferredApiService();
      final container = createContainer(api);
      final notifier = container.read(animalImagesProvider.notifier);

      // リクエストA（cat + dog）を開始
      final requestA = notifier.loadInitialImages();

      // 選択を変更して provider を再 build させ、リクエストBを開始
      container
          .read(selectedAnimalTypesProvider.notifier)
          .selectType('dog', false);
      final requestB = container
          .read(animalImagesProvider.notifier)
          .loadInitialImages();

      // 先に古いリクエストAが完了する
      api.completeFirstWith(['cat', 'dog']);
      await requestA;

      // Bはまだ進行中なので、読み込み中のままであるべき
      expect(
        container.read(animalImagesLoadingProvider),
        isTrue,
        reason: '後発リクエストBが進行中なのでローディングは解除されない',
      );

      // Bが完了したら解除され、Bの結果だけが反映される
      api.completeFirstWith(['cat']);
      await requestB;

      expect(container.read(animalImagesLoadingProvider), isFalse);
      expect(container.read(animalImagesProvider).map((i) => i.type), ['cat']);
    });

    test('画像を取得できない場合はエラー状態を通知する', () async {
      final container = createContainer(EmptyApiService());

      // ローディング／エラーの初期値を確認してから読み込む
      expect(container.read(animalImagesLoadingProvider), isFalse);
      expect(container.read(animalImagesErrorProvider), isNull);

      await container.read(animalImagesProvider.notifier).loadInitialImages();

      expect(container.read(animalImagesProvider), isEmpty);
      expect(container.read(animalImagesLoadingProvider), isFalse);
      expect(container.read(animalImagesErrorProvider), isNotNull);
    });
  });
}
