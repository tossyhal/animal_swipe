// test/api_contract_test.dart
//
// 外部API（Cataas / Dog CEO）の契約テスト。
//
// `test/fixtures/` に置いた「実際のレスポンス形状を模したファイル」を、
// 本番と同じパーサーである `lib/services/animal_source.dart` の
// `AnimalSource.buildUri` / `AnimalSource.parseResponse` に直接通す。
// ネットワークを一切使わないため決定的で、外部APIの仕様変更・
// ボット対策ページへの差し替え・CORS喪失・混在コンテンツ混入などを
// 「本番と同じコード」で検知できる。
//
// 以前の版は `AnimalSource` 抽出前のコードに合わせて `ApiService` の
// パース分岐をテスト内に複製していたが、複製ロジックはテスト対象の
// 実装が変わっても追随せず壊れないため、契約テストとしての意味が
// なくなっていた（複製と実装が同時に古くなり静かに通り続ける）。
// `AnimalSource` 抽出（#15）により本番のパース処理へ直接アクセス
// できるようになったため、複製はやめて本番コードを直接呼ぶ。
//
// HTTP ステータス（非200・タイムアウト）の扱いは `ApiService` の責務であり、
// `test/api_service_test.dart` で MockClient を使って検証済みのため
// ここでは扱わない。このファイルはレスポンスボディの「中身の契約」に絞る。
import 'dart:convert';
import 'dart:io';

import 'package:animal_swipe/models/animal_type.dart';
import 'package:animal_swipe/services/animal_source.dart';
import 'package:flutter_test/flutter_test.dart';

/// test/fixtures 配下のfixtureファイルを文字列として読み込む
String _loadFixture(String name) {
  return File('test/fixtures/$name').readAsStringSync();
}

void main() {
  group('Cataas 契約テスト（CatSource.parseResponse）', () {
    const source = CatSource();

    test('正常系: 配列要素から height 付き画像URLを構築できる', () {
      final images = source.parseResponse(_loadFixture('cataas_success.json'));

      expect(images, hasLength(1));
      expect(images.first.id, 'abc123def456');
      expect(
        images.first.url,
        'https://cataas.com/cat/abc123def456?height=$kCatImageHeight',
      );
      expect(images.first.type, AnimalType.cat);
      expect(images.first.source, 'Cat as a service');
    });

    test('異常系: 空配列の場合は例外にならず0件を返す', () {
      final images = source.parseResponse(_loadFixture('cataas_empty.json'));
      expect(images, isEmpty);
    });

    test('異常系: 不正JSONはFormatExceptionとして検知される', () {
      expect(
        () => source.parseResponse(_loadFixture('cataas_invalid_json.txt')),
        throwsFormatException,
      );
    });

    test('異常系: ボット対策HTMLページが200で返ってもFormatExceptionとして検知される'
        '（json.decode が有効なJSONとして解釈できず落ちるため、Content-Type'
        'チェックを実装していない現状のコードでも実質的に検知できている）', () {
      expect(
        () => source.parseResponse(_loadFixture('bot_protection.html')),
        throwsFormatException,
      );
    });
  });

  group('Dog CEO 契約テスト（DogSource.parseResponse・全犬種ランダム）', () {
    const source = DogSource();

    test('正常系: message配列の各要素からAnimalImageを生成できる', () {
      final images = source.parseResponse(
        _loadFixture('dog_random_success.json'),
      );

      expect(images, hasLength(1));
      expect(
        images.first.url,
        'https://images.dog.ceo/breeds/hound-afghan/n02088094_1003.jpg',
      );
      expect(Uri.parse(images.first.url).scheme, 'https');
      expect(images.first.type, AnimalType.dog);
      // URL の 'hound-afghan' フォルダ名から犬種名を復元できていること
      // （DogBreed.fromImageUrl 経由の犬種名復元。全犬種ランダムAPIの
      // レスポンス自体には犬種を表すフィールドが無いため）
      expect(images.first.description, 'Afghan Hound');
      expect(images.first.source, 'Dog CEO');
    });

    test('異常系: status != success はFormatExceptionを投げる', () {
      expect(
        () =>
            source.parseResponse(_loadFixture('dog_random_error_status.json')),
        throwsFormatException,
      );
    });

    test('異常系: message空配列は例外にならず0件を返す', () {
      final images = source.parseResponse(
        _loadFixture('dog_random_empty.json'),
      );
      expect(images, isEmpty);
    });

    test('異常系: HTMLリダイレクトページ（不正JSON）はFormatExceptionとして検知される', () {
      expect(
        () => source.parseResponse(_loadFixture('dog_html_redirect.html')),
        throwsFormatException,
      );
    });

    test('異常系: http://（非TLS）の画像URLは読み飛ばされる', () {
      // 実際に観測したことのある壊れ方ではなく仮想的なケースだが、PWA は
      // HTTPS 配信のため http:// 画像は混在コンテンツとしてブラウザに
      // ブロックされ空白カードになる。DogSource.parseResponse は該当要素を
      // 読み飛ばす（lib/services/animal_source.dart 参照）。この検証を機に
      // 追加した挙動なので、fixture ではなくインラインJSONで表現する。
      final images = source.parseResponse(
        jsonEncode({
          'status': 'success',
          'message': [
            'http://images.dog.ceo/breeds/hound-afghan/n02088094_1003.jpg',
            'https://images.dog.ceo/breeds/hound-afghan/n02088094_1004.jpg',
          ],
        }),
      );

      expect(images, hasLength(1));
      expect(Uri.parse(images.first.url).scheme, 'https');
    });
  });

  group(
    'Dog CEO 契約テスト（犬種一覧 breeds/list/all・.github/workflows/api-health.yml の監視対象）',
    () {
      // このエンドポイントは現状アプリ本体（AnimalSource）からは利用しておらず、
      // 対応する本番パーサーが存在しない（#32 の犬種選択機能での利用を想定した
      // 将来利用のためのfixture）。一方 `.github/workflows/api-health.yml` の
      // 「Dog CEO API（犬種一覧）のヘルスチェック」ステップは
      // `.status == "success"` かつ `.message` がオブジェクトであることを
      // 前提に監視している。本番コードを複製することにはならないため
      // （複製すべき本番コードがそもそも無い）、その前提が実際のレスポンス
      // 形状と一致していることをここで固定しておく。
      test('fixtureの形状がヘルスチェックワークフローの前提と一致する', () {
        final decoded =
            json.decode(_loadFixture('dog_breeds_list_all_success.json'))
                as Map<String, dynamic>;

        expect(decoded['status'], 'success');
        expect(decoded['message'], isA<Map<String, dynamic>>());

        final message = decoded['message'] as Map<String, dynamic>;
        expect(message, isNotEmpty);
        expect(message['hound'], containsAll(['afghan', 'basset']));
        expect(message['shiba'], isEmpty);
        for (final entry in message.entries) {
          expect(entry.value, isA<List<dynamic>>());
        }
      });

      test('異常系: status != success の形状も固定しておく（他fixtureを再利用）', () {
        final decoded =
            json.decode(_loadFixture('dog_random_error_status.json'))
                as Map<String, dynamic>;
        expect(decoded['status'], isNot('success'));
      });
    },
  );
}
