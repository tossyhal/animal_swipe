// test/prefs_service_test.dart
import 'package:animal_swipe/models/animal_type.dart';
import 'package:animal_swipe/services/prefs_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PrefsService テスト', () {
    late SharedPreferences prefs;
    late PrefsService prefsService;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
      prefsService = PrefsService(prefs);
    });

    group('基本機能のテスト', () {
      test('初期状態では選択済み動物タイプは空であること', () {
        final types = prefsService.getSelectedAnimalTypes();
        expect(types, isEmpty, reason: '初期状態で空リストが返されること');
        expect(
          prefsService.hasSelectedAnimalTypes(),
          isFalse,
          reason: '初期状態でhasSelectedAnimalTypesがfalseを返すこと',
        );
      });

      test('動物タイプを保存して取得できること', () async {
        // 保存
        await prefsService.saveSelectedAnimalTypes([
          AnimalType.cat,
          AnimalType.dog,
        ]);

        // 検証
        expect(prefsService.getSelectedAnimalTypes(), [
          AnimalType.cat,
          AnimalType.dog,
        ], reason: '保存した動物タイプが正しく取得できること');
        expect(
          prefsService.hasSelectedAnimalTypes(),
          isTrue,
          reason: '動物タイプが存在することが確認できること',
        );
      });

      test('空のリストを保存できること', () async {
        // まず何かデータを保存
        await prefsService.saveSelectedAnimalTypes([
          AnimalType.cat,
          AnimalType.dog,
        ]);

        // 空リストで上書き
        await prefsService.saveSelectedAnimalTypes([]);

        // 検証
        expect(
          prefsService.getSelectedAnimalTypes(),
          isEmpty,
          reason: '空リストが正しく保存されること',
        );
        expect(
          prefsService.hasSelectedAnimalTypes(),
          isFalse,
          reason: '空リストの場合はhasSelectedAnimalTypesがfalseを返すこと',
        );
      });
    });

    group('データ更新のテスト', () {
      test('既存のデータを新しいデータで上書きできること', () async {
        // 初期データを保存
        await prefsService.saveSelectedAnimalTypes([AnimalType.cat]);

        // 新しいデータで上書き
        await prefsService.saveSelectedAnimalTypes([AnimalType.dog]);

        // 検証
        expect(prefsService.getSelectedAnimalTypes(), [
          AnimalType.dog,
        ], reason: '新しいデータで正しく上書きされること');
      });

      test('重複した値は自動的に除去されること', () async {
        // 重複を含むデータを保存
        await prefsService.saveSelectedAnimalTypes([
          AnimalType.cat,
          AnimalType.cat,
          AnimalType.dog,
          AnimalType.dog,
        ]);

        // 検証
        expect(prefsService.getSelectedAnimalTypes(), [
          AnimalType.cat,
          AnimalType.dog,
        ], reason: '重複が除去されて保存されること');
        expect(prefs.getStringList('selected_animal_types'), ['cat', 'dog']);
      });
    });

    group('不正データのハンドリング', () {
      // #15 以前は文字列をそのまま保存していたため、空文字列や未知の動物名を
      // 実行時に弾く必要があった。列挙型になったことで保存側の検証は不要になり、
      // 「読み出し時に未知の id を安全に無視できるか」だけが残る。
      test('保存済みデータに未知の動物 id が混ざっていても無視される', () async {
        // 旧バージョンや将来のバージョンが書き込んだ想定のデータを直接注入
        await prefs.setStringList('selected_animal_types', [
          'cat',
          'bird',
          'dog',
          'unicorn',
        ]);

        expect(
          prefsService.getSelectedAnimalTypes(),
          [AnimalType.cat, AnimalType.dog],
          reason: '未知の id は落とし、既知のものだけを返すこと',
        );
        expect(
          prefsService.hasSelectedAnimalTypes(),
          isTrue,
          reason: '既知の id が 1 つでも残っていれば選択済みとみなすこと',
        );
      });

      test('未知の id しか残っていない場合は未選択として扱う', () async {
        await prefs.setStringList('selected_animal_types', ['bird', '']);

        expect(prefsService.getSelectedAnimalTypes(), isEmpty);
        expect(prefsService.hasSelectedAnimalTypes(), isFalse);
      });

      test('保存済みデータが重複していても 1 つに畳まれる', () async {
        await prefs.setStringList('selected_animal_types', [
          'cat',
          'cat',
          'dog',
        ]);

        expect(prefsService.getSelectedAnimalTypes(), [
          AnimalType.cat,
          AnimalType.dog,
        ]);
      });
    });

    group('データの永続性テスト', () {
      test('保存したデータがSharedPreferencesに正しく保存されていること', () async {
        // データを保存
        await prefsService.saveSelectedAnimalTypes([
          AnimalType.cat,
          AnimalType.dog,
        ]);

        // SharedPreferences には AnimalType.id の文字列で保存される。
        // 列挙子名ではなく id であることが、リネーム耐性の担保になる。
        final rawData = prefs.getStringList('selected_animal_types');
        expect(rawData, [
          'cat',
          'dog',
        ], reason: 'SharedPreferencesに正しく保存されていること');
      });

      test('新しいPrefsServiceインスタンスでも保存済みのデータを取得できること', () async {
        // 最初のインスタンスでデータを保存
        await prefsService.saveSelectedAnimalTypes([
          AnimalType.cat,
          AnimalType.dog,
        ]);

        // 新しいPrefsServiceインスタンスを作成
        final newPrefsService = PrefsService(prefs);

        // 検証
        expect(
          newPrefsService.getSelectedAnimalTypes(),
          [AnimalType.cat, AnimalType.dog],
          reason: '新しいインスタンスでも保存済みのデータを取得できること',
        );
      });
    });
  });
}
