// test/animal_model_test.dart
import 'package:animal_swipe/models/animal_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const base = AnimalImage(
    id: 'abc',
    url: 'https://example.com/abc.jpg',
    type: 'cat',
    description: 'ふわふわ',
    source: 'Cat as a service',
  );

  group('等価性', () {
    test('全フィールドが同じなら等しい', () {
      const other = AnimalImage(
        id: 'abc',
        url: 'https://example.com/abc.jpg',
        type: 'cat',
        description: 'ふわふわ',
        source: 'Cat as a service',
      );

      expect(base, other);
      expect(base.hashCode, other.hashCode);
    });

    test('1 フィールドでも違えば等しくない', () {
      expect(base == base.copyWith(id: 'xyz'), isFalse);
      expect(
        base == base.copyWith(url: 'https://example.com/xyz.jpg'),
        isFalse,
      );
      expect(base == base.copyWith(type: 'dog'), isFalse);
      expect(base == base.copyWith(description: 'もふもふ'), isFalse);
      expect(base == base.copyWith(source: 'Dog CEO'), isFalse);
    });

    test('Set / contains で値として扱える', () {
      final set = {base, base.copyWith()};

      expect(set.length, 1, reason: '同じ値は 1 つに畳まれること');
      expect(set.contains(base.copyWith()), isTrue);
    });
  });

  group('copyWith', () {
    test('引数を省略すると元の値が維持される', () {
      expect(base.copyWith(), base);
    });

    test('指定したフィールドだけが差し替わる', () {
      final updated = base.copyWith(description: 'もふもふ');

      expect(updated.description, 'もふもふ');
      expect(updated.id, base.id);
      expect(updated.url, base.url);
      expect(updated.type, base.type);
      expect(updated.source, base.source);
    });

    // null を「省略」と同義にすると、任意フィールドを消せなくなる。
    test('null を明示的に渡すと任意フィールドを消去できる', () {
      final cleared = base.copyWith(description: null, source: null);

      expect(cleared.description, isNull);
      expect(cleared.source, isNull);
      expect(cleared.id, base.id);
    });
  });

  group('JSON 変換', () {
    test('toJson -> fromJson で往復できる', () {
      expect(AnimalImage.fromJson(base.toJson()), base);
    });

    test('任意フィールドが null でも往復できる', () {
      const minimal = AnimalImage(
        id: 'abc',
        url: 'https://example.com/abc.jpg',
        type: 'dog',
      );

      final json = minimal.toJson();
      expect(json['description'], isNull);
      expect(json['source'], isNull);
      expect(AnimalImage.fromJson(json), minimal);
    });

    test('必須フィールドが欠けていたら FormatException', () {
      expect(
        () =>
            AnimalImage.fromJson(<String, dynamic>{'id': 'abc', 'type': 'cat'}),
        throwsFormatException,
      );
    });

    test('必須フィールドの型が違っても FormatException', () {
      expect(
        () => AnimalImage.fromJson(<String, dynamic>{
          'id': 1,
          'url': 'https://example.com/abc.jpg',
          'type': 'cat',
        }),
        throwsFormatException,
      );
    });

    test('任意フィールドの型が違っても FormatException', () {
      expect(
        () => AnimalImage.fromJson(<String, dynamic>{
          'id': 'abc',
          'url': 'https://example.com/abc.jpg',
          'type': 'cat',
          'description': 42,
        }),
        throwsFormatException,
      );
    });
  });

  group('fromApiJson', () {
    test('cat は id から URL を組み立てる', () {
      final image = AnimalImage.fromApiJson(<String, dynamic>{
        'id': 'c1',
      }, 'cat');

      expect(image.id, 'c1');
      expect(image.url, 'https://cataas.com/cat/c1');
      expect(image.type, 'cat');
    });

    test('dog は url をそのまま使う', () {
      final image = AnimalImage.fromApiJson(<String, dynamic>{
        'url': 'https://images.dog.ceo/breeds/hound/n02088094_1003.jpg',
      }, 'dog');

      expect(
        image.url,
        'https://images.dog.ceo/breeds/hound/n02088094_1003.jpg',
      );
      expect(image.type, 'dog');
    });

    test('未対応のタイプは例外', () {
      expect(
        () => AnimalImage.fromApiJson(<String, dynamic>{}, 'bird'),
        throwsA(isA<Exception>()),
      );
    });
  });
}
