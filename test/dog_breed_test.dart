// test/dog_breed_test.dart
import 'dart:math';

import 'package:animal_swipe/constants/app_strings.dart';
import 'package:animal_swipe/models/dog_breed.dart';
import 'package:animal_swipe/services/animal_source.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DogBreed.fromImageUrl - 単一犬種', () {
    test('親犬種だけの URL をパースできる', () {
      final breed = DogBreed.fromImageUrl(
        'https://images.dog.ceo/breeds/hound/n02088094_1003.jpg',
      );

      expect(breed, isNotNull);
      expect(breed!.breed, 'hound');
      expect(breed.subBreed, isNull);
      expect(breed.displayName, 'Hound');
    });

    // Dog CEO は「german shepherd」を 1 語のフォルダ名で持つ。
    // 語の分割はしない（推測で誤った区切りを入れない）。
    test('1 語の長い犬種名はそのまま先頭だけ大文字にする', () {
      final breed = DogBreed.fromImageUrl(
        'https://images.dog.ceo/breeds/germanshepherd/n02106662_100.jpg',
      );

      expect(breed!.breed, 'germanshepherd');
      expect(breed.displayName, 'Germanshepherd');
    });
  });

  group('DogBreed.fromImageUrl - サブ犬種', () {
    // issue に挙がっている代表例。
    // API 上は terrier の下に border がある（親子関係を保つ）が、
    // 表示は英語の一般的な並びで「Border Terrier」にする。
    test('terrier-border は Border Terrier になる', () {
      final breed = DogBreed.fromImageUrl(
        'https://images.dog.ceo/breeds/terrier-border/n02093754_1062.jpg',
      );

      expect(breed, isNotNull);
      expect(breed!.breed, 'terrier', reason: 'API 上の親犬種を保持すること');
      expect(breed.subBreed, 'border', reason: 'API 上のサブ犬種を保持すること');
      expect(breed.displayName, 'Border Terrier');
    });

    test('bulldog-french は French Bulldog になる', () {
      final breed = DogBreed.fromImageUrl(
        'https://images.dog.ceo/breeds/bulldog-french/n02108915_1000.jpg',
      );

      expect(breed!.displayName, 'French Bulldog');
    });

    // Dog CEO の実データは高々 2 要素だが、増えても落ちないこと。
    test('3 要素以上でも先頭を親犬種として扱う', () {
      final breed = DogBreed.fromImageUrl(
        'https://images.dog.ceo/breeds/terrier-border-mix/a.jpg',
      );

      expect(breed!.breed, 'terrier');
      expect(breed.subBreed, 'border mix');
      expect(breed.displayName, 'Border Mix Terrier');
    });
  });

  group('DogBreed.fromImageUrl - 不正な URL', () {
    // 例外にせず null を返し、呼び出し側でフォールバックできること。
    test('breeds セグメントが無ければ null', () {
      expect(
        DogBreed.fromImageUrl('https://images.dog.ceo/foo/hound/a.jpg'),
        isNull,
      );
    });

    test('breeds の後に犬種フォルダが無ければ null', () {
      expect(DogBreed.fromImageUrl('https://images.dog.ceo/breeds'), isNull);
      expect(DogBreed.fromImageUrl('https://images.dog.ceo/breeds/'), isNull);
    });

    test('犬種フォルダに英字以外が混ざっていれば null', () {
      expect(
        DogBreed.fromImageUrl('https://images.dog.ceo/breeds/123/a.jpg'),
        isNull,
      );
      expect(
        DogBreed.fromImageUrl('https://images.dog.ceo/breeds/hound_2/a.jpg'),
        isNull,
      );
    });

    test('ハイフンの前後が空なら null', () {
      expect(DogBreed.fromFolderName('-terrier'), isNull);
      expect(DogBreed.fromFolderName('terrier-'), isNull);
      expect(DogBreed.fromFolderName('terrier--border'), isNull);
      expect(DogBreed.fromFolderName(''), isNull);
    });

    test('URL とみなせない文字列でも例外にならない', () {
      expect(DogBreed.fromImageUrl(''), isNull);
      expect(DogBreed.fromImageUrl('not a url at all'), isNull);
      expect(DogBreed.fromImageUrl('http://['), isNull);
    });
  });

  group('DogBreed の等価性', () {
    test('同じ親犬種・サブ犬種なら等しい', () {
      const a = DogBreed(breed: 'terrier', subBreed: 'border');
      const b = DogBreed(breed: 'terrier', subBreed: 'border');

      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a == const DogBreed(breed: 'terrier'), isFalse);
    });
  });

  group('DogSource が犬種名を description に入れる', () {
    const source = DogSource();

    test('全犬種ランダムでも犬種名が付く', () {
      final images = source.parseResponse(
        '{"status":"success","message":['
        '"https://images.dog.ceo/breeds/terrier-border/a.jpg",'
        '"https://images.dog.ceo/breeds/hound/b.jpg"]}',
      );

      expect(images.map((i) => i.description), ['Border Terrier', 'Hound']);
    });

    // 完了条件: 「犬種またはフォールバック名が表示される」
    test('犬種を復元できない URL は「いぬ」にフォールバックする', () {
      final images = source.parseResponse(
        '{"status":"success","message":['
        '"https://images.dog.ceo/unknown/format/a.jpg"]}',
      );

      expect(images.single.description, AppStrings.animalDog);
      expect(images.single.description, isNotNull, reason: 'null にはしないこと');
    });

    // #32 の差し込み口。選択済みの犬種があれば URL を再解析しない。
    test('犬種が明示指定されていれば URL を再解析しない', () {
      const selected = DogSource(
        breed: DogBreed(breed: 'terrier', subBreed: 'border'),
      );

      final images = selected.parseResponse(
        '{"status":"success","message":['
        '"https://images.dog.ceo/unknown/format/a.jpg"]}',
      );

      expect(
        images.single.description,
        'Border Terrier',
        reason: 'URL からは復元できないが、選択値が保持されていること',
      );
    });

    test('犬種が明示指定されていれば犬種別エンドポイントを使う', () {
      expect(
        const DogSource(
          breed: DogBreed(breed: 'hound'),
        ).buildUri(Random()).toString(),
        'https://dog.ceo/api/breed/hound/images/random/$kImagesPerRequest',
      );
      expect(
        const DogSource(
          breed: DogBreed(breed: 'terrier', subBreed: 'border'),
        ).buildUri(Random()).toString(),
        'https://dog.ceo/api/breed/terrier/border/images/random/'
        '$kImagesPerRequest',
      );
    });
  });
}
