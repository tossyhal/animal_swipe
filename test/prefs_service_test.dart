// test/prefs_service_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:animal_swipe/services/prefs_service.dart';

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
        await prefsService.saveSelectedAnimalTypes(['cat', 'dog']);

        // 検証
        expect(prefsService.getSelectedAnimalTypes(), [
          'cat',
          'dog',
        ], reason: '保存した動物タイプが正しく取得できること');
        expect(
          prefsService.hasSelectedAnimalTypes(),
          isTrue,
          reason: '動物タイプが存在することが確認できること',
        );
      });

      test('空のリストを保存できること', () async {
        // まず何かデータを保存
        await prefsService.saveSelectedAnimalTypes(['cat', 'dog']);

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
        await prefsService.saveSelectedAnimalTypes(['cat']);

        // 新しいデータで上書き
        await prefsService.saveSelectedAnimalTypes(['dog', 'bird']);

        // 検証
        expect(prefsService.getSelectedAnimalTypes(), [
          'dog',
          'bird',
        ], reason: '新しいデータで正しく上書きされること');
      });

      test('重複した値は自動的に除去されること', () async {
        // 重複を含むデータを保存
        await prefsService.saveSelectedAnimalTypes([
          'cat',
          'cat',
          'dog',
          'dog',
        ]);

        // 検証
        expect(prefsService.getSelectedAnimalTypes(), [
          'cat',
          'dog',
        ], reason: '重複が除去されて保存されること');
      });
    });

    group('エラーハンドリングのテスト', () {
      test('型安全性が保たれていること', () async {
        // 型システムにより、nullは許可されていないため、
        // コンパイル時にnullを渡すことは不可能です。
        // 代わりに空リストで動作確認を行います。
        await prefsService.saveSelectedAnimalTypes([]);

        // 検証
        expect(
          prefsService.getSelectedAnimalTypes(),
          isEmpty,
          reason: '空リストが正しく処理されること',
        );
      });

      test('不正な値が含まれている場合はフィルタリングされること', () async {
        // 空文字を含むデータを保存
        final List<String> invalidData = ['cat', '', 'dog', '  ', 'bird'];
        await prefsService.saveSelectedAnimalTypes(invalidData);

        // 検証
        expect(prefsService.getSelectedAnimalTypes(), [
          'cat',
          'dog',
          'bird',
        ], reason: '空文字や空白文字がフィルタリングされること');
      });
    });

    group('データの永続性テスト', () {
      test('保存したデータがSharedPreferencesに正しく保存されていること', () async {
        // データを保存
        await prefsService.saveSelectedAnimalTypes(['cat', 'dog']);

        // SharedPreferencesから直接データを取得して検証
        final rawData = prefs.getStringList('selected_animal_types');
        expect(rawData, [
          'cat',
          'dog',
        ], reason: 'SharedPreferencesに正しく保存されていること');
      });

      test('新しいPrefsServiceインスタンスでも保存済みのデータを取得できること', () async {
        // 最初のインスタンスでデータを保存
        await prefsService.saveSelectedAnimalTypes(['cat', 'dog']);

        // 新しいPrefsServiceインスタンスを作成
        final newPrefsService = PrefsService(prefs);

        // 検証
        expect(
          newPrefsService.getSelectedAnimalTypes(),
          ['cat', 'dog'],
          reason: '新しいインスタンスでも保存済みのデータを取得できること',
        );
      });
    });
  });
}
