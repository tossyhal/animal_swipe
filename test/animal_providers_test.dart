// test/animal_providers_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:animal_swipe/providers/animal_providers.dart';
import 'package:animal_swipe/services/prefs_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
        notifier.selectType('cat', true);
        expect(container.read(selectedAnimalTypesProvider), [
          'cat',
        ], reason: '猫が正しく追加されていること');
      });

      test('動物タイプを削除すると、リストから削除されること', () {
        final notifier = container.read(selectedAnimalTypesProvider.notifier);
        // 準備：まず動物を追加
        notifier.selectType('dog', true);
        notifier.selectType('cat', true);

        // 実行：猫を削除
        notifier.selectType('cat', false);

        // 検証
        expect(
          container.read(selectedAnimalTypesProvider),
          ['dog'],
          reason: '猫が正しく削除され、犬のみが残っていること',
        );
      });
    });

    group('エッジケースのテスト', () {
      test('同じ動物タイプを複数回追加しても、1回だけ追加されること', () {
        final notifier = container.read(selectedAnimalTypesProvider.notifier);
        notifier.selectType('cat', true);
        notifier.selectType('cat', true);
        notifier.selectType('cat', true);

        expect(container.read(selectedAnimalTypesProvider), [
          'cat',
        ], reason: '重複した追加を防止できていること');
      });

      test('存在しない動物タイプを削除しても、エラーが発生しないこと', () {
        final notifier = container.read(selectedAnimalTypesProvider.notifier);
        // 実行時にエラーが発生しないことを確認
        expect(
          () => notifier.selectType('nonexistent', false),
          returnsNormally,
        );
      });

      test('空文字列の動物タイプは追加されないこと', () {
        final notifier = container.read(selectedAnimalTypesProvider.notifier);
        notifier.selectType('', true);

        expect(
          container.read(selectedAnimalTypesProvider),
          isEmpty,
          reason: '空文字列は無視されること',
        );
      });
    });

    group('永続化のテスト', () {
      test('選択した動物タイプがSharedPreferencesに保存されること', () async {
        final notifier = container.read(selectedAnimalTypesProvider.notifier);
        notifier.selectType('cat', true);
        notifier.selectType('dog', true);

        // SharedPreferencesに保存されていることを確認
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

        // 保存されていたデータが復元されていることを確認
        expect(
          newContainer.read(selectedAnimalTypesProvider),
          ['cat', 'dog'],
          reason: '保存されていた動物タイプが正しく復元されること',
        );

        newContainer.dispose();
      });
    });
  });
}
