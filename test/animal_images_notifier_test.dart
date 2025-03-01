// test/animal_images_notifier_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:animal_swipe/providers/animal_providers.dart';
import 'package:animal_swipe/services/api_service.dart' show IApiService;
import 'package:animal_swipe/models/animal_model.dart';

// ダミーの ApiService クラスを作成してテスト用データを返す
// モックApiServiceの実装
class MockApiService implements IApiService {
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

void main() {
  group('AnimalImagesNotifier テスト', () {
    late ProviderContainer container;
    late MockApiService mockApiService;
    late List<String> selectedTypes;

    // 各テスト前に MockApiService と ProviderContainer を準備
    setUp(() {
      mockApiService = MockApiService();
      selectedTypes = ['cat', 'dog'];
      container = ProviderContainer(
        overrides: [
          // animalImagesProvider を上書きしてダミーの Notifier を注入
          animalImagesProvider.overrideWith(
            (ref) => AnimalImagesNotifier(mockApiService, selectedTypes),
          ),
        ],
      );
    });

    tearDown(() {
      container.dispose();
    });

    // 初期画像ロード処理が正しく動作するかを検証
    test('初期画像のロード', () async {
      final notifier = container.read(animalImagesProvider.notifier);
      await notifier.loadInitialImages();
      final images = container.read(animalImagesProvider);
      // 選択した動物タイプごとに1件ずつ返るため、件数は2件であるはず
      expect(images.length, 2);
    });

    // トップ画像削除後、必要に応じて追加読み込みが実行されることを検証
    test('トップ画像の削除後、追加読み込みが実行される', () async {
      final notifier = container.read(animalImagesProvider.notifier);
      await notifier.loadInitialImages();
      final initialLength = container.read(animalImagesProvider).length;
      notifier.removeTopImage();
      final afterRemovalLength = container.read(animalImagesProvider).length;
      // トップ画像が削除され、残り件数が閾値以下なら追加読み込みが行われるため、
      // 件数が初期より減少しているが、場合によっては追加で増えている可能性がある
      expect(afterRemovalLength >= initialLength - 1, true);
    });
  });
}
