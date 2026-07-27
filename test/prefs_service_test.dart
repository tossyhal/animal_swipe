// test/prefs_service_test.dart
import 'package:animal_swipe/models/animal_model.dart';
import 'package:animal_swipe/models/animal_type.dart';
import 'package:animal_swipe/services/prefs_service.dart';
import 'package:flutter/material.dart';
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

    group('テーマモードのテスト', () {
      test('初期状態ではシステム設定に合わせるが返ること', () {
        expect(prefsService.getThemeMode(), ThemeMode.system);
      });

      test('テーマモードを保存して取得できること', () async {
        await prefsService.saveThemeMode(ThemeMode.dark);
        expect(prefsService.getThemeMode(), ThemeMode.dark);

        await prefsService.saveThemeMode(ThemeMode.light);
        expect(prefsService.getThemeMode(), ThemeMode.light);
      });

      test('保存されるのは ThemeMode.name の文字列であること', () async {
        await prefsService.saveThemeMode(ThemeMode.dark);
        expect(prefs.getString('theme_mode'), 'dark');
      });

      // #15 の AnimalType と同じ方針: 未知・破損した値でも起動を失敗させない
      test('保存済みデータが未知の文字列の場合はシステム設定にフォールバックすること', () async {
        await prefs.setString('theme_mode', 'sepia');
        expect(prefsService.getThemeMode(), ThemeMode.system);
      });

      test('新しいPrefsServiceインスタンスでも保存済みのテーマモードを取得できること', () async {
        await prefsService.saveThemeMode(ThemeMode.dark);

        final newPrefsService = PrefsService(prefs);
        expect(newPrefsService.getThemeMode(), ThemeMode.dark);
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

    group('お気に入りのテスト（#8）', () {
      const catImage = AnimalImage(
        id: 'cat-1',
        url: 'https://example.com/cat-1.jpg',
        type: AnimalType.cat,
        description: 'ふわふわ',
        source: 'Cat as a service',
      );
      const dogImage = AnimalImage(
        id: 'dog-1',
        url: 'https://example.com/dog-1.jpg',
        type: AnimalType.dog,
      );

      test('初期状態ではお気に入りは空であること', () {
        expect(prefsService.getFavorites(), isEmpty);
      });

      test('お気に入りを保存して取得できること（往復できる）', () async {
        await prefsService.saveFavorites([catImage, dogImage]);

        expect(prefsService.getFavorites(), [catImage, dogImage]);
      });

      test('新しいPrefsServiceインスタンスでも保存済みのお気に入りを取得できること', () async {
        await prefsService.saveFavorites([catImage]);

        final newPrefsService = PrefsService(prefs);

        expect(newPrefsService.getFavorites(), [catImage]);
      });

      test('JSON全体が壊れている場合は空リストとして扱い、落ちないこと', () async {
        await prefs.setString('favorite_animal_images', '{ this is not json');

        expect(prefsService.getFavorites(), isEmpty);
      });

      test('JSONが配列でない場合は空リストとして扱うこと', () async {
        await prefs.setString('favorite_animal_images', '{"foo": "bar"}');

        expect(prefsService.getFavorites(), isEmpty);
      });

      test('一部の要素だけ壊れていても、残りは復元されること', () async {
        // 1件目は正常、2件目は type が未知、3件目は必須フィールド欠落
        await prefs.setString(
          'favorite_animal_images',
          '['
              '{"id":"cat-1","url":"https://example.com/cat-1.jpg","type":"cat","description":null,"source":null},'
              '{"id":"x","url":"https://example.com/x.jpg","type":"unicorn"},'
              '{"id":"y"}'
              ']',
        );

        expect(prefsService.getFavorites(), [
          const AnimalImage(
            id: 'cat-1',
            url: 'https://example.com/cat-1.jpg',
            type: AnimalType.cat,
          ),
        ]);
      });
    });
  });
}
