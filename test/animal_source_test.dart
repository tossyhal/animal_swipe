// test/animal_source_test.dart
import 'dart:math';

import 'package:animal_swipe/models/animal_type.dart';
import 'package:animal_swipe/services/animal_source.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AnimalType', () {
    test('fromId で既知の id を引ける', () {
      expect(AnimalType.fromId('cat'), AnimalType.cat);
      expect(AnimalType.fromId('dog'), AnimalType.dog);
    });

    test('fromId は未知の id に対して null を返す', () {
      expect(AnimalType.fromId('bird'), isNull);
      expect(AnimalType.fromId(''), isNull);
      expect(AnimalType.fromId('CAT'), isNull, reason: '大文字小文字は区別すること');
    });

    test('fromIds は未知の id を捨て、重複を畳み、順序を保つ', () {
      expect(AnimalType.fromIds(['dog', 'bird', 'cat', 'dog']), [
        AnimalType.dog,
        AnimalType.cat,
      ]);
    });

    // 列挙子をリネームしても保存済みデータが壊れないよう、
    // 永続化には Enum.name ではなく id を使う。
    test('id は列挙子名と独立に定義されている', () {
      for (final type in AnimalType.values) {
        expect(type.id, isNotEmpty);
        expect(type.label, isNotEmpty);
        expect(type.emoji, isNotEmpty);
      }
      // id の重複がないこと
      expect(
        AnimalType.values.map((t) => t.id).toSet().length,
        AnimalType.values.length,
      );
    });
  });

  group('AnimalSource レジストリ', () {
    // 「新しい動物はクラスを 1 つ足すだけ」を成立させるための番人。
    // 列挙子だけ足してソースの登録を忘れると、ここで落ちる。
    test('全ての AnimalType にソースが登録されている', () {
      for (final type in AnimalType.values) {
        final source = AnimalSource.forType(type);
        expect(source, isNotNull, reason: '${type.id} のソースが未登録');
        expect(source!.type, type, reason: '${type.id} のソースが別の型を名乗っている');
      }
    });
  });

  group('CatSource', () {
    const source = CatSource();

    test('URL に件数とランダムな skip が付く', () {
      final uri = source.buildUri(Random(42));

      expect(uri.host, 'cataas.com');
      expect(uri.path, '/api/cats');
      expect(uri.queryParameters['limit'], '$kImagesPerRequest');
      final skip = int.parse(uri.queryParameters['skip']!);
      expect(skip, inInclusiveRange(0, 999));
    });

    // Random をフィールド化した効果。同じシードなら同じ URL になる。
    test('同じシードなら同じ URL になる', () {
      expect(source.buildUri(Random(7)), source.buildUri(Random(7)));
    });

    test('正常なレスポンスをパースできる', () {
      final images = source.parseResponse('[{"id":"a1"},{"id":"a2"}]');

      expect(images.length, 2);
      expect(images.first.id, 'a1');
      expect(images.first.url, 'https://cataas.com/cat/a1?height=1600');
      expect(images.first.type, AnimalType.cat);
    });

    // 原寸画像が毎回ダウンロードされる問題（#7）への対応。
    // Cataas は /cat/{id}?height= でサーバー側リサイズに対応している。
    // 表示は BoxFit.cover のポートレートペインなので、横長画像でも
    // アップスケールされないよう width ではなく height を指定する。
    test('画像 URL に Cataas の height パラメータが付く', () {
      final images = source.parseResponse('[{"id":"a1"}]');

      final uri = Uri.parse(images.first.url);
      expect(uri.queryParameters['height'], '$kCatImageHeight');
      expect(uri.queryParameters.containsKey('width'), isFalse);
    });

    test('id が欠けている要素は読み飛ばす', () {
      final images = source.parseResponse('[{"id":"a1"},{},{"id":""},"x"]');

      expect(images.map((i) => i.id), ['a1']);
    });

    test('配列でないレスポンスは FormatException', () {
      expect(() => source.parseResponse('{"id":"a1"}'), throwsFormatException);
    });

    test('不正な JSON は例外', () {
      expect(() => source.parseResponse('not json'), throwsFormatException);
    });
  });

  group('DogSource', () {
    const source = DogSource();

    test('全犬種ランダム取得の URL を組み立てる', () {
      final uri = source.buildUri(Random(42));

      expect(uri.toString(), 'https://dog.ceo/api/breeds/image/random/10');
    });

    test('正常なレスポンスをパースできる', () {
      final images = source.parseResponse(
        '{"message":["https://images.dog.ceo/breeds/hound/a.jpg"],'
        '"status":"success"}',
      );

      expect(images.length, 1);
      expect(images.first.url, 'https://images.dog.ceo/breeds/hound/a.jpg');
      expect(images.first.type, AnimalType.dog);
    });

    // Dog CEO はリサイズ用のクエリパラメータに対応していないため、
    // Cataas と違い URL には一切手を加えない（#7）。
    test('Dog CEO の URL にはリサイズ用パラメータを付けない（非対応のため）', () {
      final images = source.parseResponse(
        '{"message":["https://images.dog.ceo/breeds/hound/a.jpg"],'
        '"status":"success"}',
      );

      expect(
        images.first.url,
        'https://images.dog.ceo/breeds/hound/a.jpg',
        reason: '画像 URL をそのまま使い、クエリパラメータを追加しない',
      );
    });

    test('status が success でなければ FormatException', () {
      expect(
        () => source.parseResponse('{"message":[],"status":"error"}'),
        throwsFormatException,
      );
    });

    test('message が配列でなければ FormatException', () {
      expect(
        () => source.parseResponse('{"message":"boom","status":"success"}'),
        throwsFormatException,
      );
    });

    test('オブジェクトでないレスポンスは FormatException', () {
      expect(() => source.parseResponse('[]'), throwsFormatException);
    });

    test('空文字列の要素は読み飛ばす', () {
      final images = source.parseResponse(
        '{"message":["","https://images.dog.ceo/breeds/hound/a.jpg"],'
        '"status":"success"}',
      );

      expect(images.length, 1);
    });
  });
}
