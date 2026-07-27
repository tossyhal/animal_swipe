// test/animal_providers_test.dart
import 'package:animal_swipe/models/animal_type.dart';
import 'package:animal_swipe/providers/animal_providers.dart';
import 'package:animal_swipe/services/prefs_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
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
}
